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
        panel.dataSource = self
        panel.reloadData()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    func numberOfPreviewItems(in _: QLPreviewPanel?) -> Int {
        url == nil ? 0 : 1
    }

    func previewPanel(_: QLPreviewPanel?, previewItemAt _: Int) -> QLPreviewItem? {
        url as NSURL?
    }
}
