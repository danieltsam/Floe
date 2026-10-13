//
//  BookmarksTests.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

@testable import Floe
import Foundation
import Testing

@MainActor struct BookmarksTests {
    private let file = Data("""
    {"checksum": "x", "version": 1, "roots": {
      "bookmark_bar": {"type": "folder", "name": "Bookmarks Bar", "children": [
        {"type": "url", "name": "Floe on GitHub", "url": "https://github.com/thaw-app/Floe"},
        {"type": "folder", "name": "Work", "children": [
          {"type": "url", "name": "", "url": "https://example.com/invoices"},
          {"type": "url", "name": "A script", "url": "javascript:alert(1)"}
        ]}
      ]},
      "other": {"type": "folder", "name": "Other", "children": [
        {"type": "url", "name": "Tide tables", "url": "https://tides.example.org/today"}
      ]}
    }}
    """.utf8)

    @Test func linksAreReadThroughFoldersAndOnlyWebAddressesAreKept() {
        let found = Bookmarks.parse(file, browser: "Vivaldi")
        #expect(found.map(\.title) == ["Floe on GitHub", "https://example.com/invoices", "Tide tables"])
        #expect(found.map(\.label) == ["github.com", "example.com", "tides.example.org"])
        #expect(found.allSatisfy { $0.browser == "Vivaldi" })
        #expect(Bookmarks.parse(Data("not json".utf8), browser: "Vivaldi").isEmpty)
        #expect(Bookmarks.parse(Data(#"{"roots": 3}"#.utf8), browser: "Vivaldi").isEmpty)
    }

    @Test func everyProfileOfEveryBrowserIsReadAndAnAddressIsListedOnce() throws {
        let support = FileManager.default.temporaryDirectory.appendingPathComponent("floe-bookmarks-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: support) }
        for profile in ["Vivaldi/Default", "Vivaldi/Profile 1", "Vivaldi/System Profile", "net.imput.helium/Default"] {
            let folder = support.appendingPathComponent(profile)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try file.write(to: folder.appendingPathComponent("Bookmarks"))
        }
        let found = Bookmarks.read(support: support)
        #expect(found.count == 3, "the same address in two profiles and two browsers is one row")
        #expect(Set(found.map(\.browser)) == ["Vivaldi"], "the first browser that has it names it")
        #expect(Bookmarks.read(support: support.appendingPathComponent("missing")).isEmpty)
    }

    @Test func theScopeRanksByTitleAndSiteAndOpensTheAddress() async throws {
        let scope = BookmarkSearchScope(read: { [file] in Bookmarks.parse(file, browser: "Vivaldi") })
        let context = SearchContext(query: "bookmarks tide")
        let text = try #require(scope.text(in: context))
        var rows: [RootItem] = []
        for await batch in try #require(scope.updates(for: text, context: context)) {
            rows = batch
        }
        #expect(rows.map(\.title) == ["Tide tables"])
        #expect(rows.first?.rowLabel == "tides.example.org")
        #expect(rows.first?.id == "bookmark:https://tides.example.org/today")
        #expect(rows.first?.isScopeResult == true)
        #expect(BookmarkSearchScope.ranked(Bookmarks.parse(file, browser: "Vivaldi"), query: "github").map(\.title) == ["Floe on GitHub"])
        #expect(scope.text(in: SearchContext(query: "bookmarks")) == nil, "the word alone is an ordinary search")
    }
}
