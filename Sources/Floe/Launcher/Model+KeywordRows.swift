//
//  Model+KeywordRows.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import Foundation

/// The rows a keyword finds outside the catalog, such as a window, a package or a sound device: what Return
/// says and does on each, and what its Actions menu holds.
extension LauncherModel {
    /// What Return does, as its button says it. Nil for a row that is none of these.
    static func keywordRowTitle(for item: RootItem) -> String? {
        switch item {
        case let .window(row): title(for: row)
        case let .brew(package): title(for: Homebrew.primaryVerb(for: package))
        case let .soundDevice(row): title(for: row.device.role)
        case .qrCode: String(localized: "Copy Image", bundle: .floe, comment: "A button that copies a picture.")
        case .place: String(localized: "Open in Maps", bundle: .floe, comment: "Maps is the name of Apple's app.")
        default: nil
        }
    }

    /// Return on one of these rows. False for a row that is none of them, which nothing was done to.
    func openKeywordRow(_ item: RootItem) -> Bool {
        switch item {
        case let .window(row): open(row)
        case let .brew(package): brew(Homebrew.primaryVerb(for: package), package)
        case .noteDesk: openNoteDesk()
        case let .soundDevice(row): use(row)
        case let .qrCode(text): copyQRCode(for: text)
        case let .place(place): reach(Places.link(to: place))
        default: return false
        }
        return true
    }

    /// The Actions menu after what Return does. Nil for a row that is none of these.
    func keywordRowActions(for item: RootItem) -> [ItemAction?]? {
        switch item {
        case let .window(.window(window)): windowActions(for: window)
        case let .brew(package): brewActions(for: package)
        case let .qrCode(text): qrCodeActions(for: text)
        case let .place(place): placeActions(for: place)
        default: nil
        }
    }
}
