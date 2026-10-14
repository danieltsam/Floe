//
//  Model+Places.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import AppKit

extension LauncherModel {
    func placeActions(for place: Place) -> [ItemAction?] {
        [
            nil,
            ItemAction(title: String(localized: "Get Directions", bundle: .floe, comment: "A button that opens the way to a place in Maps."), symbol: "arrow.triangle.turn.up.right.diamond") { [weak self] in
                self?.reach(Places.link(to: place, directions: true))
            },
            ItemAction(title: String(localized: "Copy Address", bundle: .floe), symbol: "doc.on.doc") { [weak self] in
                NSPasteboard.general.copy(place.address.isEmpty ? place.name : place.address)
                self?.showHUD(String(localized: "Copied", bundle: .floe, comment: "Shown briefly after something was put on the clipboard."))
            },
        ]
    }
}
