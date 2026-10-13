//
//  Model+Brew.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import AppKit

extension LauncherModel {
    static func title(for verb: Homebrew.Verb) -> String {
        switch verb {
        case .install: String(localized: "Install in Terminal", bundle: .floe, comment: "A button that runs the command installing a Homebrew package in the terminal.")
        case .upgrade: String(localized: "Upgrade in Terminal", bundle: .floe, comment: "A button that runs the command upgrading a Homebrew package in the terminal.")
        case .uninstall: String(localized: "Uninstall in Terminal", bundle: .floe, comment: "A button that runs the command removing a Homebrew package in the terminal.")
        }
    }

    /// Hands the command to the terminal: there it shows what it does and asks for a password when it needs one.
    func brew(_ verb: Homebrew.Verb, _ package: BrewPackage) {
        let terminal = searchContext().preferredApps.first { $0.role == .terminal }?.app
        runShellCommand(Homebrew.command(verb, package), terminal: terminal, inTerminal: true)
    }

    func brewActions(for package: BrewPackage) -> [ItemAction?] {
        var actions: [ItemAction?] = [nil]
        if package.isInstalled {
            actions.append(ItemAction(title: Self.title(for: .uninstall), symbol: "trash") { [weak self] in self?.brew(.uninstall, package) })
        }
        actions.append(ItemAction(title: String(localized: "Copy Name", bundle: .floe, comment: "A button that copies the name of the selected thing."), symbol: "doc.on.doc") { [weak self] in
            NSPasteboard.general.copy(package.name)
            self?.showHUD(String(localized: "Copied \(package.name)", bundle: .floe, comment: "Shown briefly after copying. The placeholder is what was copied, such as a file name."))
        })
        return actions
    }
}
