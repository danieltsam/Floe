//
//  Model+Sound.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import Foundation

extension LauncherModel {
    static func title(for role: AudioRole) -> String {
        switch role {
        case .output: String(localized: "Use for Sound Output", bundle: .floe, comment: "A button that makes the selected device the one sound plays through.")
        case .input: String(localized: "Use as Microphone", bundle: .floe, comment: "A button that makes the selected device the one that records.")
        }
    }

    /// Return on a sound device: the panel goes, and the HUD says where sound goes now.
    func use(_ row: SoundDeviceRow) {
        hidePanel()
        reset()
        showHUD(SoundDevices.use(row.device))
    }
}
