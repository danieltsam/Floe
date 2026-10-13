//
//  Model+RowKeys.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import AppKit

extension LauncherModel {
    /// A key that means something only on the kind of row that is selected: Tab completes a shell
    /// suggestion, and Command-Y shows a file in Quick Look. False for any other key or row.
    func handleRowKey(_ event: NSEvent, _ flags: NSEvent.ModifierFlags) -> Bool {
        guard results.indices.contains(selection) else { return false }
        switch (event.keyCode, results[selection].item) {
        case let (48, .shell(row, _)) where flags.isEmpty && row.origin != .typed:
            complete(with: row)
        case let (16, .file(file)) where flags == .command:
            QuickLookPresenter.shared.show(file.url)
        default:
            return false
        }
        return true
    }
}
