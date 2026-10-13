//
//  WindowSearchScope.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import Foundation

/// `windows invoice`: the open windows that match, to switch to one. The word alone lists them all.
/// Reading them needs Accessibility; without it the scope is one row that says so.
struct WindowSearchScope: SearchScope {
    let keyword = OpenWindows.keyword
    let title = String(localized: "Open Windows", bundle: .floe)
    let emptyTitle = String(localized: "No open window matches", bundle: .floe)
    var isTrusted: () -> Bool = { MenuBarExtras.isTrusted }
    var scan: @Sendable () -> [OpenWindow] = OpenWindows.scan

    func text(in context: SearchContext) -> String? {
        context.text(afterOrAlone: keyword)
    }

    func results(for _: String, context _: SearchContext) -> [RootItem] {
        isTrusted() ? [] : [.window(.access)]
    }

    /// Each window is a round trip to its app, so they are read off the main thread, fresh for every query.
    func updates(for text: String, context _: SearchContext) -> AsyncStream<[RootItem]>? {
        guard isTrusted() else { return nil }
        return .once { [scan] in Self.rows(scan(), query: text) }
    }

    static nonisolated func rows(_ windows: [OpenWindow], query: String) -> [RootItem] {
        ranked(windows, query: query).map { .window(.window($0)) }
    }

    /// Windows whose title or app matches, best first. Without a query, all of them in the order they were read.
    static nonisolated func ranked(_ windows: [OpenWindow], query: String) -> [OpenWindow] {
        guard !query.isEmpty else { return windows }
        return windows.ranked { Ranking.menuBarScore(query: query, name: $0.title, owner: $0.appName) }
    }
}
