//
//  QuickLookPresenter.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import AppKit
import Quartz

/// Shows one file in the system's Quick Look panel, for a row that stands for a file.
final class QuickLookPresenter: NSObject, QLPreviewPanelDataSource {
    static let shared = QuickLookPresenter()
    private(set) var url: URL?

    func show(_ url: URL) {
        self.url = url
        guard let panel = QLPreviewPanel.shared() else { return }
        NSApp.activate()
        if panel.dataSource === self {
            panel.reloadData()
        }
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in _: QLPreviewPanel?) -> Int {
        url == nil ? 0 : 1
    }

    func previewPanel(_: QLPreviewPanel?, previewItemAt _: Int) -> QLPreviewItem? {
        url as NSURL?
    }
}

/// The panel asks the responder chain who controls it, and the app's delegate is the end of that chain.
/// AppKit declares the three calls without an actor and makes them on the main thread.
extension AppDelegate {
    override nonisolated func acceptsPreviewPanelControl(_: QLPreviewPanel?) -> Bool {
        MainActor.assumeIsolated { QuickLookPresenter.shared.url != nil }
    }

    override nonisolated func beginPreviewPanelControl(_ panel: QLPreviewPanel?) {
        MainActor.assumeIsolated { panel?.dataSource = QuickLookPresenter.shared }
    }

    override nonisolated func endPreviewPanelControl(_ panel: QLPreviewPanel?) {
        MainActor.assumeIsolated { panel?.dataSource = nil }
    }
}
