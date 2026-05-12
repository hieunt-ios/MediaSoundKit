//
//  EffectSliderView.swift
//  MediaSoundKit
//
//  Created by Codex on 12/5/26.
//

import UIKit

final class EffectSliderView: UIView {

    // MARK: - Properties

    var valueChanged: ((Float) -> Void)?

    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let slider = UISlider()
    private let contentStackView = UIStackView()
    private let headerStackView = UIStackView()
    private let valueFormatter: (Float) -> String

    // MARK: - Init

    init(
        title: String,
        minimumValue: Float,
        maximumValue: Float,
        initialValue: Float,
        valueFormatter: @escaping (Float) -> String
    ) {
        self.valueFormatter = valueFormatter
        super.init(frame: .zero)

        titleLabel.text = title
        slider.minimumValue = minimumValue
        slider.maximumValue = maximumValue
        slider.value = initialValue
        valueLabel.text = valueFormatter(initialValue)

        setupUI()
        addComponents()
        setupLayout()
        bindData()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public

    func setValue(_ value: Float) {
        slider.value = value
        valueLabel.text = valueFormatter(value)
    }
}

// MARK: - Setup

private extension EffectSliderView {
    func setupUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 8
        layer.masksToBounds = true

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label

        valueLabel.font = .preferredFont(forTextStyle: .subheadline)
        valueLabel.textColor = .secondaryLabel
        valueLabel.textAlignment = .right

        headerStackView.axis = .horizontal
        headerStackView.alignment = .center
        headerStackView.distribution = .fill
        headerStackView.spacing = 12

        contentStackView.axis = .vertical
        contentStackView.spacing = 12
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
    }

    func addComponents() {
        addSubview(contentStackView)

        headerStackView.addArrangedSubview(titleLabel)
        headerStackView.addArrangedSubview(valueLabel)

        contentStackView.addArrangedSubview(headerStackView)
        contentStackView.addArrangedSubview(slider)
    }

    func setupLayout() {
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }

    func bindData() {
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
    }

    @objc func sliderValueChanged() {
        let value = slider.value
        valueLabel.text = valueFormatter(value)
        valueChanged?(value)
    }
}

