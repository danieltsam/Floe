//
//  Model+Search.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import Foundation

extension LauncherModel {
    /// An untouched selection follows the new pinned answer; an explicitly selected row stays selected.
    func showDefinitionRows() {
        let followsFirst = selection == 0
        showSourceRows()
        if followsFirst {
            selection = 0
        }
    }

    /// Everything the search providers may know, read once per search.
    func searchContext() -> SearchContext {
        var context = SearchContext(query: query)
        context.definition = definitionSearch.definition
        context.favorites = settings.favorites
        context.hidden = Set(settings.hiddenResults.keys)
        context.emojiSkinTone = settings.emojiSkinTone
        context.shell = settings.shell
        context.searchSources = settings.searchSources
        context.checkpoints = checkpoints
        context.reminderLists = context.trimmed.lowercased().hasPrefix(ReminderDraft.keyword + " ") ? reminding.lists() : []
        context.timers = runningTimers.all
        context.focusShortcut = settings.focusShortcut
        context.aliases = settings.aliases
        context.notesApp = settings.notesApp
        context.frecency = { [usage] in usage.frecency(of: $0) }
        context.commands = commands
        context.scripts = allScripts
        context.apps = apps
        context.thawActions = Thaw.actions()
        context.preferredApps = resolvedApps.apps
        context.clipboardDestination = clipboardDestination
        context.settingsPanes = settingsPanes
        context.sshHosts = sshHosts
        context.shortcuts = shortcutsForSearch
        context.snippets = SnippetStore.shared.snippets
        context.quicklinks = QuicklinkStore.shared.links
        context.menuBarItemNames = settings.menuBarItemNames
        context.canAskAI = !query.isEmpty && canAskAI()
        return context
    }
}
