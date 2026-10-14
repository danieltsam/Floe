//
//  AnswerRow.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import AppKit

/// Something Floe worked out from what was typed: a time elsewhere, a new identifier, a text changed. Return copies it.
nonisolated struct AnswerRow: Hashable, Sendable {
    /// Never holds the answer, so nothing that stores a row's id stores it.
    var id: String
    /// The answer on one line, as the row shows it.
    var title: String
    var subtitle: String?
    /// Beside the title: what kind of answer this is.
    var kind: String
    var symbol: String
    /// What Return copies.
    var text: String
    /// A password: clipboard managers are asked not to keep it.
    var isSecret = false
    /// Where Return goes when the row has nothing to copy, such as the settings that would make an answer possible.
    var link: URL?
    /// What Return's button says when the row has a link.
    var linkTitle: String?

    init(id: String, text: String, subtitle: String? = nil, kind: String, symbol: String, isSecret: Bool = false) {
        self.id = "answer:" + id
        self.text = text
        title = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        self.subtitle = subtitle
        self.kind = kind
        self.symbol = symbol
        self.isSecret = isSecret
    }
}

/// `time in tokyo`, `uuid`, `base64 hello`: each leads with its answer.
struct AnswerRowSearchProvider: SearchProvider {
    /// What a bare `base64` works on. Read only when the query is one of the words that change a text.
    var clipboard: () -> String? = { NSPasteboard.general.string(forType: .string) }
    var facts = SystemFacts.Readers()

    func contribution(for context: SearchContext) -> SearchContribution {
        // Under the ranked rows: "disk" still opens Disk Utility with Return.
        let found = SystemFacts.rows(for: context.trimmed, readers: facts)
        if !found.isEmpty {
            return SearchContribution(appended: found.map { RootResult(item: .answer($0), section: nil) })
        }
        guard let row = row(for: context) else { return SearchContribution() }
        return SearchContribution(pinned: [RootResult(item: .answer(row), section: nil)])
    }

    private func row(for context: SearchContext) -> AnswerRow? {
        if let place = context.text(after: WorldTime.keyword) {
            return WorldTime.row(for: place)
        }
        if let row = Generators.row(for: context.trimmed) {
            return row
        }
        guard let change = TextChange.allCases.first(where: { context.trimmed.lowercased().hasPrefix($0.rawValue) }) else { return nil }
        let typed = context.text(after: change.rawValue)
        guard typed != nil || context.trimmed.lowercased() == change.rawValue else { return nil }
        return (typed ?? clipboard()).flatMap(change.row)
    }
}
