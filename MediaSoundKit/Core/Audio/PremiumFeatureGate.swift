//
//  PremiumFeatureGate.swift
//  MediaSoundKit
//
//  Created by Codex on 12/5/26.
//

import Foundation

protocol PremiumFeatureGate {
    var canUseVolumeBoost: Bool { get }
}

struct DefaultPremiumFeatureGate: PremiumFeatureGate {
    let canUseVolumeBoost: Bool

    static let free = DefaultPremiumFeatureGate(canUseVolumeBoost: false)
    static let premium = DefaultPremiumFeatureGate(canUseVolumeBoost: true)
}

