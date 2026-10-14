//
//  Model+RowOwners.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import AppKit

extension LauncherModel {
    /// The features that own rows, asked in turn what a row's Return, actions and keys do.
    var rowOwners: [any RowOwner] {
        [shellRows, checkpointRows, timerRows, reminderRows, eventRows, receiptRows]
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

    func makeCheckpointRows() -> CheckpointRows {
        let rows = CheckpointRows()
        rows.host = CheckpointRows.Host(
            hidePanel: { [weak self] in self?.panelHost.hidePanel() },
            showHUD: { [weak self] in self?.panelHost.showHUD($0) },
            leave: { [weak self] in self?.leave() },
            record: { [weak self] in self?.record($0) },
            showOutput: { [weak self] in self?.shellRows.environment.showOutput($0, $1) },
            openLink: { [weak self] in self?.openLink($0) },
            chosenEditor: { [weak self] in
                guard let self else { return nil }
                // Only an editor the user chose: the role's stand-in is the app text files open in anyway.
                return PreferredApps.chosenApp(settings.appChoice(for: .editor), installed: resolvedApps.lookup)
            }
        )
        return rows
    }

    func makeTimerRows() -> TimerRows {
        let rows = TimerRows()
        rows.host = TimerRows.Host(
            showHUD: { [weak self] in self?.panelHost.showHUD($0) },
            leave: { [weak self] in self?.leave() },
            record: { [weak self] in self?.record($0) },
            toResident: { [weak self] in self?.panelHost.residentRequests }
        )
        return rows
    }

    func makeReminderRows() -> ReminderRows {
        let rows = ReminderRows()
        rows.host = ReminderRows.Host(showHUD: { [weak self] in self?.panelHost.showHUD($0) }, leave: { [weak self] in self?.leave() }, record: { [weak self] in self?.record($0) })
        return rows
    }

    func makeEventRows() -> EventRows {
        let rows = EventRows()
        rows.host = EventRows.Host(
            showHUD: { [weak self] in self?.panelHost.showHUD($0) },
            leave: { [weak self] in self?.leave() },
            record: { [weak self] in self?.record($0) },
            openLink: { [weak self] in self?.openLink($0) }
        )
        return rows
    }

    /// Hides the panel and goes back to the root search.
    func leave() {
        panelHost.hidePanel()
        reset()
    }

    func makeReceiptRows() -> ReceiptRows {
        let rows = ReceiptRows()
        rows.host = ReceiptRows.Host(
            hidePanel: { [weak self] in self?.panelHost.hidePanel() },
            showHUD: { [weak self] in self?.panelHost.showHUD($0) },
            refresh: { [weak self] in self?.refresh() },
            showOutput: { [weak self] in self?.shellRows.environment.showOutput($0, $1) },
            runCommand: { [weak self] in self?.shellRows.runShellCommand($0, terminal: nil) },
            commandsChanged: { [weak self] in self?.catalog.reloadCommands() },
            keepsReceipts: { [weak self] in self?.settings.keepsReceipts ?? false },
            toResident: { [weak self] in self?.panelHost.residentRequests },
            deleter: { [weak self] kind in
                guard let self else { return { _ in false } }
                return switch kind {
                case .event: eventRows.environment.delete
                case .checkpoint: checkpointRows.deleteCheckpoint
                case .timer: timerRows.stopTimer
                default: reminderRows.environment.delete
                }
            }
        )
        return rows
    }

    /// Keeps a receipt of something Floe did, unless the user switched that off.
    func record(_ receipt: Receipt) {
        receiptRows.record(receipt)
    }
}
