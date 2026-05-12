//
//  MediaAudioEngine.swift
//  MediaSoundKit
//
//  Created by Codex on 12/5/26.
//

import AVFoundation
import AudioToolbox
import Accelerate

protocol AudioProcessingControlling: AnyObject {
    var playbackState: PlaybackState { get }
    var bassConfiguration: BassBoostConfiguration { get }
    var equalizerConfiguration: GraphicEqualizerConfiguration { get }
    var volumeConfiguration: VolumeBoostConfiguration { get }

    func loadAudio(from url: URL) throws
    func play() throws
    func pause()
    func stop()
    func updateBassBoost(_ configuration: BassBoostConfiguration)
    func updateGraphicEqualizer(_ configuration: GraphicEqualizerConfiguration)
    func updateVolumeBoost(_ configuration: VolumeBoostConfiguration) throws
    func currentSpectrum() -> [Float]
}

final class MediaAudioEngine: AudioProcessingControlling {

    // MARK: - Properties

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let bassEQ = AVAudioUnitEQ(numberOfBands: 1)
    private let graphicEQ = AVAudioUnitEQ(numberOfBands: 6)
    private let preampGainNode = AVAudioMixerNode()
    private let compressorNode = MediaAudioEngine.makeDynamicsProcessorNode()
    private let limiterNode = MediaAudioEngine.makePeakLimiterNode()
    private let softClipperNode = AVAudioUnitDistortion()
    private let volumeBoostNode = AVAudioMixerNode()
    private let premiumGate: PremiumFeatureGate
    private let spectrumAnalyzer = SpectrumAnalyzer()

    private var audioFile: AVAudioFile?

    private(set) var playbackState: PlaybackState = .idle
    private(set) var bassConfiguration: BassBoostConfiguration = .disabled
    private(set) var equalizerConfiguration: GraphicEqualizerConfiguration = .flat
    private(set) var volumeConfiguration: VolumeBoostConfiguration = .disabled

    // MARK: - Init

    init(premiumGate: PremiumFeatureGate = DefaultPremiumFeatureGate.free) {
        self.premiumGate = premiumGate
        configureAudioSession()
        configureAudioGraph()
        updateBassBoost(.disabled)
        updateGraphicEqualizer(.flat)
        applyLoudnessBoost(.disabled)
    }

    deinit {
        engine.stop()
        engine.mainMixerNode.removeTap(onBus: 0)
    }

    // MARK: - Public

    func loadAudio(from url: URL) throws {
        let file = try AVAudioFile(forReading: url)
        guard file.length > 0 else {
            throw AudioCoreError.invalidAudioFile
        }

        audioFile = file
        playbackState = .ready
    }

    func play() throws {
        guard let audioFile else {
            throw AudioCoreError.fileNotLoaded
        }

        if !engine.isRunning {
            try engine.start()
        }

        if playerNode.isPlaying {
            return
        }

        playerNode.stop()
        playerNode.scheduleFile(audioFile, at: nil) { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                if self.playbackState == .playing {
                    self.playbackState = .stopped
                }
            }
        }

        playerNode.play()
        playbackState = .playing
    }

    func pause() {
        guard playerNode.isPlaying else { return }
        playerNode.pause()
        playbackState = .paused
    }

    func stop() {
        playerNode.stop()
        playbackState = audioFile == nil ? .idle : .stopped
    }

    func updateBassBoost(_ configuration: BassBoostConfiguration) {
        bassConfiguration = configuration

        guard let band = bassEQ.bands.first else { return }
        band.filterType = .lowShelf
        band.frequency = configuration.frequency
        band.bandwidth = 0.8
        band.gain = configuration.isEnabled ? configuration.gain : 0
        band.bypass = !configuration.isEnabled
        bassEQ.globalGain = 0
    }

    func updateGraphicEqualizer(_ configuration: GraphicEqualizerConfiguration) {
        equalizerConfiguration = configuration

        for (index, bandConfiguration) in configuration.bands.enumerated() {
            guard graphicEQ.bands.indices.contains(index) else { continue }

            let band = graphicEQ.bands[index]
            band.filterType = .parametric
            band.frequency = bandConfiguration.frequency
            band.bandwidth = 1
            band.gain = configuration.isEnabled ? bandConfiguration.gain : 0
            band.bypass = !configuration.isEnabled
        }
    }

    func updateVolumeBoost(_ configuration: VolumeBoostConfiguration) throws {
        guard configuration.isEnabled == false || premiumGate.canUseVolumeBoost else {
            throw AudioCoreError.premiumFeatureRequired
        }

        volumeConfiguration = configuration
        applyLoudnessBoost(configuration)
    }

    func currentSpectrum() -> [Float] {
        spectrumAnalyzer.currentSpectrum
    }
}

// MARK: - Private

private extension MediaAudioEngine {
    func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            assertionFailure("Failed to configure audio session: \(error.localizedDescription)")
        }
    }

    func configureAudioGraph() {
        engine.attach(playerNode)
        engine.attach(bassEQ)
        engine.attach(graphicEQ)
        engine.attach(preampGainNode)
        engine.attach(compressorNode)
        engine.attach(limiterNode)
        engine.attach(softClipperNode)
        engine.attach(volumeBoostNode)

        engine.connect(playerNode, to: bassEQ, format: nil)
        engine.connect(bassEQ, to: graphicEQ, format: nil)
        engine.connect(graphicEQ, to: preampGainNode, format: nil)
        engine.connect(preampGainNode, to: compressorNode, format: nil)
        engine.connect(compressorNode, to: limiterNode, format: nil)
        engine.connect(limiterNode, to: softClipperNode, format: nil)
        engine.connect(softClipperNode, to: volumeBoostNode, format: nil)
        engine.connect(volumeBoostNode, to: engine.mainMixerNode, format: nil)

        configureCompressor()
        configureLimiter()
        configureSoftClipper()
        installSpectrumTap()
    }

    static func makeDynamicsProcessorNode() -> AVAudioUnitEffect {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_DynamicsProcessor,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        return AVAudioUnitEffect(audioComponentDescription: description)
    }

    static func makePeakLimiterNode() -> AVAudioUnitEffect {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        return AVAudioUnitEffect(audioComponentDescription: description)
    }

    func configureCompressor() {
        setParameter(kDynamicsProcessorParam_Threshold, value: -18, on: compressorNode)
        setParameter(kDynamicsProcessorParam_HeadRoom, value: 5, on: compressorNode)
        setParameter(kDynamicsProcessorParam_ExpansionRatio, value: 1, on: compressorNode)
        setParameter(kDynamicsProcessorParam_ExpansionThreshold, value: -60, on: compressorNode)
        setParameter(kDynamicsProcessorParam_AttackTime, value: 0.003, on: compressorNode)
        setParameter(kDynamicsProcessorParam_ReleaseTime, value: 0.08, on: compressorNode)
        setParameter(kDynamicsProcessorParam_OverallGain, value: 0, on: compressorNode)
    }

    func configureLimiter() {
        setParameter(kLimiterParam_AttackTime, value: 0.001, on: limiterNode)
        setParameter(kLimiterParam_DecayTime, value: 0.08, on: limiterNode)
        setParameter(kLimiterParam_PreGain, value: 0, on: limiterNode)
    }

    func configureSoftClipper() {
        softClipperNode.loadFactoryPreset(.speechRadioTower)
        softClipperNode.preGain = -6
        softClipperNode.wetDryMix = 0
    }

    func applyLoudnessBoost(_ configuration: VolumeBoostConfiguration) {
        guard configuration.isEnabled else {
            preampGainNode.outputVolume = 1
            setParameter(kDynamicsProcessorParam_OverallGain, value: 0, on: compressorNode)
            setParameter(kLimiterParam_PreGain, value: 0, on: limiterNode)
            softClipperNode.wetDryMix = 0
            volumeBoostNode.outputVolume = 1
            return
        }

        let preampMultiplier = min(configuration.multiplier, 3)
        let makeupMultiplier = max(configuration.multiplier / preampMultiplier, 1)
        let softClipMix = configuration.softClipAmount * 45

        preampGainNode.outputVolume = preampMultiplier
        setParameter(kDynamicsProcessorParam_OverallGain, value: configuration.softClipAmount * 8, on: compressorNode)
        setParameter(kLimiterParam_PreGain, value: configuration.softClipAmount * 4, on: limiterNode)
        softClipperNode.wetDryMix = softClipMix
        volumeBoostNode.outputVolume = makeupMultiplier
    }

    func setParameter(_ address: AudioUnitParameterID, value: Float, on node: AVAudioUnitEffect) {
        node.auAudioUnit.parameterTree?
            .parameter(withAddress: AUParameterAddress(address))?
            .value = value
    }

    func installSpectrumTap() {
        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: 1_024,
            format: engine.mainMixerNode.outputFormat(forBus: 0)
        ) { [weak spectrumAnalyzer] buffer, _ in
            spectrumAnalyzer?.process(buffer: buffer)
        }
    }
}

private final class SpectrumAnalyzer {

    // MARK: - Properties

    private let fftSize = 1_024
    private let log2n = vDSP_Length(log2(Float(1_024)))
    private let queue = DispatchQueue(label: "com.mediasoundkit.spectrum")
    private let fftSetup: FFTSetup?
    private var latestSpectrum: [Float] = []

    var currentSpectrum: [Float] {
        queue.sync { latestSpectrum }
    }

    // MARK: - Init

    init() {
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
    }

    deinit {
        if let fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }

    // MARK: - Public

    func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?.pointee else { return }

        let frameCount = Int(buffer.frameLength)
        guard frameCount == fftSize, let fftSetup else { return }

        var real = [Float](repeating: 0, count: frameCount / 2)
        var imaginary = [Float](repeating: 0, count: frameCount / 2)
        var magnitudes = [Float](repeating: 0, count: frameCount / 2)

        real.withUnsafeMutableBufferPointer { realPointer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryPointer in
                var splitComplex = DSPSplitComplex(
                    realp: realPointer.baseAddress!,
                    imagp: imaginaryPointer.baseAddress!
                )

                channelData.withMemoryRebound(to: DSPComplex.self, capacity: frameCount / 2) {
                    vDSP_ctoz($0, 2, &splitComplex, 1, vDSP_Length(frameCount / 2))
                }

                vDSP_fft_zrip(
                    fftSetup,
                    &splitComplex,
                    1,
                    log2n,
                    FFTDirection(FFT_FORWARD)
                )

                vDSP_zvmags(
                    &splitComplex,
                    1,
                    &magnitudes,
                    1,
                    vDSP_Length(frameCount / 2)
                )
            }
        }

        var normalized = [Float](repeating: 0, count: magnitudes.count)
        var scale = Float(1.0 / Float(frameCount))
        vDSP_vsmul(magnitudes, 1, &scale, &normalized, 1, vDSP_Length(magnitudes.count))

        queue.async { [weak self] in
            self?.latestSpectrum = normalized
        }
    }
}
