//
//  Generators.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import Foundation
import Synchronization

/// `uuid`, `password 24` and `lorem 3`: something new to paste.
nonisolated enum Generators {
    static let uuidKeyword = "uuid"
    static let passwordKeyword = "password"
    static let loremKeyword = "lorem"
    static let passwordLengths = 8 ... 128
    static let mostParagraphs = 20

    private static let passwordCharacters = Array("abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#$%^&*-_=+")
    private static let paragraph = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

    /// The answer made for the last query. The search asks again while a query stands, and the row must not change under the user.
    private static let last = Mutex<(query: String, row: AnswerRow)?>(nil)

    /// The row for a query that is one of the words, alone or with its number. `password` needs its length,
    /// so the word alone still finds the Passwords app.
    static func row(for query: String) -> AnswerRow? {
        let query = query.lowercased()
        return last.withLock { last in
            if let last, last.query == query {
                return last.row
            }
            var random = SystemRandomNumberGenerator()
            let row = make(for: query, using: &random)
            last = row.map { (query, $0) }
            return row
        }
    }

    static func make(for query: String, using random: inout some RandomNumberGenerator) -> AnswerRow? {
        let words = query.split(separator: " ")
        guard let word = words.first, words.count <= 2 else { return nil }
        let number = words.count == 2 ? Int(words[1]) : nil
        guard words.count == 1 || number != nil else { return nil }
        switch (String(word), number) {
        case (uuidKeyword, nil):
            return AnswerRow(id: "uuid", text: UUID().uuidString.lowercased(), kind: "UUID", symbol: "number")
        case (passwordKeyword, let length?) where passwordLengths.contains(length):
            let password = String((0 ..< length).compactMap { _ in passwordCharacters.randomElement(using: &random) })
            return AnswerRow(id: "password", text: password, kind: String(localized: "Password", bundle: .floe, comment: "The kind of a result, shown beside its title. Here a password Floe made up."), symbol: "key", isSecret: true)
        case (loremKeyword, _) where (1 ... mostParagraphs).contains(number ?? 1):
            let text = Array(repeating: paragraph, count: number ?? 1).joined(separator: "\n\n")
            return AnswerRow(id: "lorem", text: text, kind: String(localized: "Placeholder Text", bundle: .floe, comment: "The kind of a result, shown beside its title. Here lorem ipsum, the filler text designers use."), symbol: "text.alignleft")
        default:
            return nil
        }
    }
}
