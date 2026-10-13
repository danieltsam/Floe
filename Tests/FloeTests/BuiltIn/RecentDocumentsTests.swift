//
//  RecentDocumentsTests.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

@testable import Floe
import Foundation
import Testing

@MainActor struct RecentDocumentsTests {
    private let preview = AppEntry(name: "Preview", url: URL(fileURLWithPath: "/System/Applications/Preview.app"))
    private let pages = AppEntry(name: "Pages", url: URL(fileURLWithPath: "/Applications/Pages.app"))
    private let day = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func used(_ name: String, ago: TimeInterval) -> RecentDocuments.Used {
        RecentDocuments.Used(url: URL(fileURLWithPath: "/floe-tests/\(name)"), date: day.addingTimeInterval(-ago))
    }

    /// PDFs open in Preview and everything else in Pages.
    private let opener: @Sendable (URL) -> URL? = { url in
        URL(fileURLWithPath: url.pathExtension == "pdf" ? "/System/Applications/Preview.app" : "/Applications/Pages.app")
    }

    @Test func onlyTheFilesTheAppOpensAreKeptInTheirOrder() {
        let files = [used("a.pdf", ago: 10), used("letter.pages", ago: 20), used("b.pdf", ago: 30)]
        #expect(RecentDocuments.documents(of: preview.url, among: files, opener: opener).map(\.url.lastPathComponent) == ["a.pdf", "b.pdf"])
        #expect(RecentDocuments.documents(of: pages.url, among: files, opener: opener).map(\.url.lastPathComponent) == ["letter.pages"])
        #expect(RecentDocuments.documents(of: preview.url, among: files, opener: { _ in nil }).isEmpty)
    }

    @Test func noMoreThanTheLimitsAreAskedAboutOrShown() {
        let many = (0 ..< 500).map { used("file\($0).pdf", ago: TimeInterval($0)) }
        var asked = 0
        let kept = RecentDocuments.documents(of: preview.url, among: many) { url in
            asked += 1
            return opener(url)
        }
        #expect(kept.count == RecentDocuments.rowLimit)
        #expect(asked == RecentDocuments.rowLimit, "asking stops once the rows are full")
        asked = 0
        _ = RecentDocuments.documents(of: pages.url, among: many) { url in
            asked += 1
            return opener(url)
        }
        #expect(asked == RecentDocuments.askedLimit)
    }

    @Test func anAppIsNamedInFullOrByItsStart() {
        let apps = [pages, preview]
        #expect(RecentDocuments.app(named: "preview", in: apps)?.name == preview.name)
        #expect(RecentDocuments.app(named: "pre", in: apps)?.name == preview.name)
        #expect(RecentDocuments.app(named: "p", in: apps)?.name == pages.name)
        #expect(RecentDocuments.app(named: "keynote", in: apps)?.name == nil)
    }

    @Test func theScopeListsTheAppsFilesAndAsksNothingForAnUnknownApp() async throws {
        let files = [used("a.pdf", ago: 10), used("letter.pages", ago: 20)]
        let scope = RecentDocumentsScope(recentlyUsed: { files }, opener: opener)
        var context = SearchContext(query: "recent preview")
        context.apps = [pages, preview]
        let text = try #require(scope.text(in: context))
        var rows: [RootItem] = []
        for await batch in try #require(scope.updates(for: text, context: context)) {
            rows = batch
        }
        #expect(rows.map(\.title) == ["a.pdf"])
        #expect(rows.first?.id == "file:/floe-tests/a.pdf")
        #expect(scope.updates(for: "keynote", context: context) == nil)
        #expect(scope.text(in: SearchContext(query: "recent")) == nil, "the word alone is an ordinary search")
    }
}
