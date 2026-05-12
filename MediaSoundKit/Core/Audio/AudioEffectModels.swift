//
//  AudioEffectModels.swift
//  MediaSoundKit
//
//  Created by Codex on 12/5/26.
//

import Foundation

enum AudioCoreError: LocalizedError {
    case fileNotLoaded
    case premiumFeatureRequired
    case invalidAudioFile

    var errorDescription: String? {
        switch self {
        case .fileNotLoaded:
            return "Audio file has not been loaded."
        case .premiumFeatureRequired:
            return "Volume boost requires premium access."
        case .invalidAudioFile:
            return "The selected audio file is invalid."
        }
    }
}

enum PlaybackState: Equatable {
    case idle
    case ready
    case playing
    case paused
    case stopped
}

struct BassBoostConfiguration: Equatable {
    var isEnabled: Bool
    var gain: Float
    var frequency: Float

    static let disabled = BassBoostConfiguration(
        isEnabled: false,
        gain: 0,
        frequency: 80
    )

    init(isEnabled: Bool, gain: Float, frequency: Float = 80) {
        self.isEnabled = isEnabled
        self.gain = min(max(gain, 0), 24)
        self.frequency = min(max(frequency, 40), 250)
    }
}

struct VolumeBoostConfiguration: Equatable {
    var isEnabled: Bool
    var multiplier: Float
    var softClipAmount: Float

    static let disabled = VolumeBoostConfiguration(
        isEnabled: false,
        multiplier: 1,
        softClipAmount: 0
    )

    init(isEnabled: Bool, multiplier: Float, softClipAmount: Float = 0.35) {
        self.isEnabled = isEnabled
        self.multiplier = min(max(multiplier, 1), 6)
        self.softClipAmount = min(max(softClipAmount, 0), 1)
    }
}

struct GraphicEqualizerBand: Equatable {
    let frequency: Float
    var gain: Float

    init(frequency: Float, gain: Float) {
        self.frequency = frequency
        self.gain = min(max(gain, -12), 12)
    }
}

struct GraphicEqualizerConfiguration: Equatable {
    var isEnabled: Bool
    var bands: [GraphicEqualizerBand]

    static let flat = GraphicEqualizerConfiguration(
        isEnabled: false,
        bands: GraphicEqualizerPreset.flat.bands
    )
}

enum GraphicEqualizerPreset {
    case flat
    case acoustic
    case bass
    case hiphop

    var bands: [GraphicEqualizerBand] {
        zip(Self.frequencies, gains).map {
            GraphicEqualizerBand(frequency: $0.0, gain: $0.1)
        }
    }

    private var gains: [Float] {
        switch self {
        case .flat:
            return [0, 0, 0, 0, 0, 0]
        case .acoustic:
            return [3, 2, 1, 2, 3, 4]
        case .bass:
            return [9, 6, 2, 0, -1, -2]
        case .hiphop:
            return [7, 5, 1, 2, 4, 3]
        }
    }

    private static let frequencies: [Float] = [150, 400, 1_000, 2_000, 6_000, 12_000]
}
