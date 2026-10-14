//
//  Model+Catalog.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import Foundation

extension LauncherModel {
    var apps: [AppEntry] {
        catalog.apps
    }

    var allCommands: [ExtensionCommand] {
        catalog.allCommands
    }

    var allScripts: [ScriptCommand] {
        catalog.allScripts
    }

    var scriptFailures: [ScriptFailure] {
        catalog.scriptFailures
    }

    var settingsPanes: [SystemSettingsPane] {
        catalog.settingsPanes
    }

    var sshHosts: [SSHHost] {
        catalog.sshHosts
    }

    var isLoadingCatalog: Bool {
        catalog.isLoading
    }

    /// Starts the first scans. Called after the panel and its subscriptions exist, so what they publish is heard.
    /// The resident loads what hotkeys and background work need, never what only the search reads.
    func startCatalogLoading() {
        catalog.reloadAll()
        if !isResident {
            catalog.reloadSettingsPanes()
        }
    }

    func catalogChanged(_ part: CatalogStore.Part) {
        switch part {
        case .apps:
            // What is installed decides the roles' fallbacks, so a change resolves them again.
            invalidateResolvedApps()
            refresh()
        case .commands, .scripts:
            refresh()
        case .settingsPanes, .sshHosts:
            // Nothing to redraw without a query: these are only searched for.
            if !query.isEmpty {
                refresh()
            }
        }
    }
}
