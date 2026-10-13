//
//  AnswerRowTests.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

@testable import Floe
import Foundation
import Testing

/// One at a time: a generated answer is kept per query for the whole process.
@Suite(.serialized) struct AnswerRowTests {
    private let mexico = TimeZone(identifier: "America/Mexico_City")!
    private let english = Locale(identifier: "en_US")
    /// Monday 12 October 2026, 10:00 in Mexico City.
    private var now: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = mexico
        return calendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 10))!
    }

    /// The row for a place, with the narrow space the system puts before AM and PM made an ordinary one.
    private func time(_ text: String) -> AnswerRow? {
        guard var row = WorldTime.row(for: text, now: now, here: mexico, locale: english) else { return nil }
        row.title = row.title.replacingOccurrences(of: "\u{202F}", with: " ")
        row.text = row.text.replacingOccurrences(of: "\u{202F}", with: " ")
        return row
    }

    private func pinned(_ query: String, clipboard: String? = nil) -> [RootItem] {
        AnswerRowSearchProvider(clipboard: { clipboard }).contribution(for: SearchContext(query: query)).pinned.map(\.item)
    }

    @Test func aPlaceIsFoundByCityAliasOrAbbreviation() {
        #expect(WorldTime.zone(named: "Tokyo")?.zone.identifier == "Asia/Tokyo")
        #expect(WorldTime.zone(named: "new york")?.place == "New York")
        #expect(WorldTime.zone(named: "sf")?.zone.identifier == "America/Los_Angeles")
        #expect(WorldTime.zone(named: "sf")?.place == "SF")
        #expect(WorldTime.zone(named: "berl")?.zone.identifier == "Europe/Berlin", "the start of a city finds it")
        #expect(WorldTime.zone(named: "utc")?.zone.secondsFromGMT() == 0)
        #expect(WorldTime.zone(named: "be") == nil, "two letters are too few to guess a city from")
        #expect(WorldTime.zone(named: "nowhere at all") == nil)
    }

    @Test func theTimeElsewhereIsShownWithHowFarItIs() throws {
        let row = try #require(time("in tokyo"))
        #expect(row.title == "1:00 AM, Tuesday in Tokyo")
        #expect(row.text == "1:00 AM")
        #expect(row.subtitle == "15 hours ahead of here")
        #expect(time("Tokyo")?.title == row.title)
        #expect(time("los angeles")?.subtitle == "1 hour behind here")
        #expect(time("mexico city")?.subtitle == "The same time as here")
    }

    @Test func aTimeOfDayHereIsTakenThere() {
        #expect(time("5pm in berlin")?.title == "1:00 AM, Tuesday in Berlin")
        #expect(time("9:30 am in berlin")?.text == "5:30 PM")
        #expect(time("17:00 in berlin")?.text == "1:00 AM")
        #expect(time("soon in berlin") == nil)
    }

    @Test func theGeneratorsAnswerOnlyTheirOwnWords() throws {
        var random = SystemRandomNumberGenerator()
        let uuid = try #require(Generators.make(for: "uuid", using: &random))
        #expect(UUID(uuidString: uuid.text) != nil)
        #expect(uuid.id == "answer:uuid", "the id never holds the answer")
        let password = try #require(Generators.make(for: "password 24", using: &random))
        #expect(password.text.count == 24)
        #expect(password.isSecret)
        #expect(password.id == "answer:password")
        #expect(Generators.make(for: "password", using: &random) == nil, "the word alone still finds the Passwords app")
        #expect(Generators.make(for: "password 4", using: &random) == nil)
        #expect(Generators.make(for: "password 500", using: &random) == nil)
        #expect(Generators.make(for: "lorem", using: &random)?.text.hasPrefix("Lorem ipsum") == true)
        #expect(Generators.make(for: "lorem 3", using: &random)?.text.components(separatedBy: "\n\n").count == 3)
        #expect(Generators.make(for: "lorem 99", using: &random) == nil)
        #expect(Generators.make(for: "uuid 3", using: &random) == nil)
        #expect(Generators.make(for: "lorem ipsum dolor", using: &random) == nil)
    }

    @Test func aGeneratedAnswerStaysWhileItsQueryStands() {
        let first = Generators.row(for: "uuid")
        #expect(first != nil)
        #expect(Generators.row(for: "UUID") == first)
        #expect(Generators.row(for: "password 12") != nil)
        #expect(Generators.row(for: "uuid") != first, "asked again after another query, it is a new one")
    }

    @Test func aTextIsChangedAndWhatCannotBeReadGivesNothing() {
        #expect(TextChange.base64.applied(to: "hello") == "aGVsbG8=")
        #expect(TextChange.unbase64.applied(to: "aGVsbG8=\n") == "hello")
        #expect(TextChange.unbase64.row(for: "not base64!") == nil)
        #expect(TextChange.urlencode.applied(to: "a b&c/d") == "a%20b%26c%2Fd")
        #expect(TextChange.urldecode.applied(to: "a%20b%26c") == "a b&c")
        #expect(TextChange.uppercase.applied(to: "Floe") == "FLOE")
        #expect(TextChange.lowercase.applied(to: "Floe") == "floe")
        #expect(TextChange.titlecase.applied(to: "the tide rises") == "The Tide Rises")
        #expect(TextChange.sha256.applied(to: "abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        #expect(TextChange.base64.row(for: "") == nil)
    }

    @Test func theProviderPinsOneAnswerAndABareWordWorksOnTheClipboard() {
        #expect(pinned("base64 hello").map(\.title) == ["aGVsbG8="])
        #expect(pinned("Base64 hello").first?.kind == "Base64")
        #expect(pinned("uppercase", clipboard: "from the clipboard").map(\.title) == ["FROM THE CLIPBOARD"])
        #expect(pinned("uppercase", clipboard: nil).isEmpty)
        #expect(pinned("uppercased text").isEmpty, "a longer word is not the keyword")
        #expect(pinned("time in tokyo").first?.kind == "Time")
        #expect(pinned("time").isEmpty)
        #expect(pinned("timer 5 minutes").isEmpty)
        #expect(pinned("uuid").first?.id == "answer:uuid")
        #expect(pinned("tide").isEmpty)
    }

    @Test func aQuicklinkWithTheSameKeywordKeepsIt() {
        var context = SearchContext(query: "time in tokyo")
        context.quicklinks = [Quicklink(name: "Time", keyword: "time", url: "https://time.is/{query}")]
        #expect(AnswerRowSearchProvider(clipboard: { nil }).contribution(for: context).pinned.isEmpty)
    }
}
