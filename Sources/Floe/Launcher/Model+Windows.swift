//
//  Model+Windows.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import AppKit

extension LauncherModel {
    static func title(for row: WindowRow) -> String {
        switch row {
        case .window: String(localized: "Switch to Window", bundle: .floe)
        case .access: String(localized: "Open Privacy Settings", bundle: .floe, comment: "A button that opens the Privacy pane of System Settings.")
        }
    }

    /// Return on a window: the launcher goes first, so the window comes forward over nothing of Floe's.
    func open(_ row: WindowRow) {
        switch row {
        case let .window(window):
            hidePanel()
            reset()
            OpenWindows.focus(window)
        case .access:
            MenuBarExtras.requestAccess()
        }
    }

    func windowActions(for window: OpenWindow) -> [ItemAction?] {
        var actions: [ItemAction?] = [nil]
        if !window.isMinimized {
            actions.append(ItemAction(title: String(localized: "Minimize Window", bundle: .floe), symbol: "minus.rectangle") { [weak self] in
                OpenWindows.minimize(window)
                self?.rescanWindows()
            })
        }
        actions.append(ItemAction(title: String(localized: "Close Window", bundle: .floe), symbol: "xmark.rectangle") { [weak self] in
            OpenWindows.close(window)
            self?.rescanWindows()
        })
        return actions
    }

    /// A refresh leaves a scope with the same query alone, so the scope is let go first and the windows are read again.
    private func rescanWindows() {
        activeScope = nil
        refresh()
    }
}
