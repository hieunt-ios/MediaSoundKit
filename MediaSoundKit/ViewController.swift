//
//  ViewController.swift
//  MediaSoundKit
//
//  Created by Nguyễn Trung Hiếu on 11/5/26.
//

import UIKit
import UniformTypeIdentifiers

final class ViewController: BaseViewController {

    // MARK: - Properties

    private let audioEngine: AudioProcessingControlling = MediaAudioEngine(
        premiumGate: DefaultPremiumFeatureGate.premium
    )

    private let scrollView = UIScrollView()
    private let contentStackView = UIStackView()

    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let selectFileButton = UIButton(type: .system)
    private let playButton = UIButton(type: .system)
    private let pauseButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)

    private let bassSwitch = UISwitch()
    private let volumeBoostSwitch = UISwitch()
    private let equalizerSegmentedControl = UISegmentedControl(items: ["Flat", "Acoustic", "Bass", "Hiphop"])

    private lazy var bassSliderView = EffectSliderView(
        title: "Bass Boost",
        minimumValue: 0,
        maximumValue: 24,
        initialValue: 8,
        valueFormatter: { "\(Int($0)) dB" }
    )

    private lazy var volumeSliderView = EffectSliderView(
        title: "Premium Loudness Boost",
        minimumValue: 1,
        maximumValue: 6,
        initialValue: 2.5,
        valueFormatter: { String(format: "%.1fx", $0) }
    )

    // MARK: - Setup

    override func setupUI() {
        view.backgroundColor = .systemBackground

        titleLabel.text = "Media Sound Kit"
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        statusLabel.text = "Select an audio file to start."
        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0

        configureButton(selectFileButton, title: "Select Audio")
        configureButton(playButton, title: "Play")
        configureButton(pauseButton, title: "Pause")
        configureButton(stopButton, title: "Stop")

        equalizerSegmentedControl.selectedSegmentIndex = 2
        equalizerSegmentedControl.selectedSegmentTintColor = .systemGreen

        contentStackView.axis = .vertical
        contentStackView.spacing = 16
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
    }

    override func addComponents() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStackView)

        contentStackView.addArrangedSubview(titleLabel)
        contentStackView.addArrangedSubview(statusLabel)
        contentStackView.addArrangedSubview(selectFileButton)
        contentStackView.addArrangedSubview(makePlaybackStackView())
        contentStackView.addArrangedSubview(makeSectionTitleLabel("Equalizer Preset"))
        contentStackView.addArrangedSubview(equalizerSegmentedControl)
        contentStackView.addArrangedSubview(makeSwitchRow(title: "Enable Bass Boost", switchView: bassSwitch))
        contentStackView.addArrangedSubview(bassSliderView)
        contentStackView.addArrangedSubview(makeSwitchRow(title: "Enable Premium Volume Boost", switchView: volumeBoostSwitch))
        contentStackView.addArrangedSubview(volumeSliderView)
    }

    override func setupLayout() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    override func bindData() {
        selectFileButton.addTarget(self, action: #selector(selectFileButtonTapped), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        pauseButton.addTarget(self, action: #selector(pauseButtonTapped), for: .touchUpInside)
        stopButton.addTarget(self, action: #selector(stopButtonTapped), for: .touchUpInside)
        bassSwitch.addTarget(self, action: #selector(bassSwitchChanged), for: .valueChanged)
        volumeBoostSwitch.addTarget(self, action: #selector(volumeBoostSwitchChanged), for: .valueChanged)
        equalizerSegmentedControl.addTarget(self, action: #selector(equalizerPresetChanged), for: .valueChanged)

        bassSliderView.valueChanged = { [weak self] value in
            self?.applyBassBoost(gain: value)
        }

        volumeSliderView.valueChanged = { [weak self] value in
            self?.applyVolumeBoost(multiplier: value)
        }

        applyEqualizerPreset(.bass)
    }
}

// MARK: - Actions

private extension ViewController {
    @objc func selectFileButtonTapped() {
        let supportedTypes: [UTType] = [.audio, .mpeg4Audio, .mp3, .wav]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    @objc func playButtonTapped() {
        do {
            try audioEngine.play()
            updateStatus("Playing")
        } catch {
            updateStatus(error.localizedDescription)
        }
    }

    @objc func pauseButtonTapped() {
        audioEngine.pause()
        updateStatus("Paused")
    }

    @objc func stopButtonTapped() {
        audioEngine.stop()
        updateStatus("Stopped")
    }

    @objc func bassSwitchChanged() {
        applyBassBoost(gain: 8)
    }

    @objc func volumeBoostSwitchChanged() {
        applyVolumeBoost(multiplier: 2.5)
    }

    @objc func equalizerPresetChanged() {
        switch equalizerSegmentedControl.selectedSegmentIndex {
        case 1:
            applyEqualizerPreset(.acoustic)
        case 2:
            applyEqualizerPreset(.bass)
        case 3:
            applyEqualizerPreset(.hiphop)
        default:
            applyEqualizerPreset(.flat)
        }
    }
}

// MARK: - Audio

private extension ViewController {
    func applyBassBoost(gain: Float) {
        let configuration = BassBoostConfiguration(
            isEnabled: bassSwitch.isOn,
            gain: gain,
            frequency: 80
        )
        audioEngine.updateBassBoost(configuration)
    }

    func applyVolumeBoost(multiplier: Float) {
        do {
            let softClipAmount = min(max((multiplier - 1) / 5, 0), 1)
            let configuration = VolumeBoostConfiguration(
                isEnabled: volumeBoostSwitch.isOn,
                multiplier: multiplier,
                softClipAmount: softClipAmount
            )
            try audioEngine.updateVolumeBoost(configuration)
        } catch {
            volumeBoostSwitch.setOn(false, animated: true)
            updateStatus(error.localizedDescription)
        }
    }

    func applyEqualizerPreset(_ preset: GraphicEqualizerPreset) {
        let configuration = GraphicEqualizerConfiguration(
            isEnabled: preset != .flat,
            bands: preset.bands
        )
        audioEngine.updateGraphicEqualizer(configuration)
    }

    func updateStatus(_ text: String) {
        statusLabel.text = text
    }
}

// MARK: - Factory

private extension ViewController {
    func configureButton(_ button: UIButton, title: String) {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(
            top: 12,
            leading: 16,
            bottom: 12,
            trailing: 16
        )
        button.configuration = configuration
    }

    func makePlaybackStackView() -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: [playButton, pauseButton, stopButton])
        stackView.axis = .horizontal
        stackView.spacing = 12
        stackView.distribution = .fillEqually
        return stackView
    }

    func makeSwitchRow(title: String, switchView: UISwitch) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        let stackView = UIStackView(arrangedSubviews: [titleLabel, switchView])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 12
        stackView.distribution = .fill
        return stackView
    }

    func makeSectionTitleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }
}

// MARK: - UIDocumentPickerDelegate

extension ViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }

        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            try audioEngine.loadAudio(from: url)
            updateStatus("Loaded: \(url.lastPathComponent)")
        } catch {
            updateStatus(error.localizedDescription)
        }
    }
}
