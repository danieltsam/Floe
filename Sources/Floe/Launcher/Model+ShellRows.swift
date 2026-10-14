//
//  Model+ShellRows.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import AppKit

extension LauncherModel {
    /// The features that own rows, asked in turn what a row's Return, actions and keys do.
    var rowOwners: [any RowOwner] {
        [shellRows]
    }

    func ownerReturnTitle(for item: RootItem) -> String? {
        rowOwners.lazy.compactMap { $0.returnTitle(for: item) }.first
    }

    func openByOwner(_ item: RootItem, flags: NSEvent.ModifierFlags = []) -> Bool {
        rowOwners.contains { $0.open(item, flags: flags) }
    }

    func ownerActions(for item: RootItem) -> [ItemAction?]? {
        rowOwners.lazy.compactMap { $0.actions(for: item) }.first
    }

    /// The shell's rows, handed what they ask of the launcher.
    func makeShellRows() -> ShellRows {
        let rows = ShellRows(settings: settings)
        rows.host = ShellRows.Host(
            hidePanel: { [weak self] in self?.panelHost.hidePanel() },
            showHUD: { [weak self] in self?.panelHost.showHUD($0) },
            leave: { [weak self] in
                // Before the panel goes back to the root, which empties the search.
                self?.rememberQuery()
                self?.panelHost.hidePanel()
                self?.reset()
            },
            record: { [weak self] in self?.record($0) },
            setQuery: { [weak self] in
                self?.query = $0
                self?.focusToken += 1
            },
            refresh: { [weak self] in self?.refresh() },
            scriptsChanged: { [weak self] in self?.catalog.reloadScripts() }
        )
        return rows
    }
}
