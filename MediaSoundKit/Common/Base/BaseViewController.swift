//
//  BaseViewController.swift
//  MediaSoundKit
//
//  Created by Codex on 12/5/26.
//

import UIKit

class BaseViewController: UIViewController {

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        addComponents()
        setupLayout()
        bindData()
    }

    // MARK: - Setup

    func setupUI() {}

    func addComponents() {}

    func setupLayout() {}

    func bindData() {}
}

