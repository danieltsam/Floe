//
//  Model+MoreRows.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import AppKit

/// Rows that no feature owns yet: keywords, dictionary definitions, answers, bookmarks and the notes desk. What Return
/// does on each, what its button says and what its menu holds. Owned rows are asked of their feature first.
extension LauncherModel {
    /// What Return does on one of these rows, as its button says it. Nil for any other row.
    static func laterTitle(for item: RootItem) -> String? {
        if case .keyword = item {
            return String(localized: "Type Keyword", bundle: .floe, comment: "A button that puts the selected keyword into the search field, for the user to go on typing.")
        }
        if case .definition = item {
            return String(localized: "Open in Dictionary", bundle: .floe, comment: "Dictionary is the name of Apple's app.")
        }
        if case let .answer(row) = item {
            return row.link == nil ? String(localized: "Copy to Clipboard", bundle: .floe) : row.linkTitle ?? String(localized: "Open", bundle: .floe, comment: "A verb on a button: open the selected result.")
        }
        return nil
    }

    /// Return on one of these rows.
    func openLater(_ item: RootItem) {
        if openByOwner(item) {
            return
        } else if case .noteDesk = item {
            openNoteDesk()
        } else {
            openTyped(item)
        }
    }

    /// Return on a row that makes, stops or reaches something from what was typed.
    private func openTyped(_ item: RootItem) {
        switch item {
        case let .keyword(hint): type(hint)
        case let .definition(definition): reach(definition.link)
        default: openFound(item)
        }
    }

    /// What the dictionary says about the word goes to the clipboard.
    private func copy(_ definition: WordDefinition) {
        NSPasteboard.general.copy(definition.text)
        panelHost.showHUD(String(localized: "Copied \(definition.word)", bundle: .floe, comment: "Shown briefly after copying. The placeholder is what was copied, such as a file name."))
        panelHost.hidePanel()
        reset()
    }

    /// Return on something the search found or worked out: a bookmark opens, and an answer goes to the clipboard,
    /// a password marked so that clipboard managers leave it alone.
    private func openFound(_ item: RootItem) {
        if case let .bookmark(bookmark) = item {
            reach(bookmark.url)
        }
        guard case let .answer(row) = item else { return }
        if let link = row.link {
            panelHost.hidePanel()
            reset()
            NSWorkspace.shared.open(link)
            return
        }
        if row.isSecret {
            NSPasteboard.general.copySecret(row.text)
        } else {
            NSPasteboard.general.copy(row.text)
        }
        panelHost.showHUD(String(localized: "Copied Answer", bundle: .floe))
        panelHost.hidePanel()
        reset()
    }

    /// Puts a keyword into the search, ready for the rest to be typed after it.
    func type(_ hint: KeywordHint) {
        query = hint.typed
        focusToken += 1
    }

    /// The Actions menu of one of these rows, after what Return does.
    func laterActions(for item: RootItem) -> [ItemAction?] {
        if case let .definition(definition) = item {
            return [ItemAction(title: String(localized: "Copy Definition", bundle: .floe), symbol: "doc.on.doc") { [weak self] in self?.copy(definition) }]
        }
        return ownerActions(for: item) ?? []
    }

    /// Hands a note to the app the user chose. What is written into a folder of notes leaves a receipt.
    func writeNote(_ action: NoteAction, text: String) {
        let record: (Receipt) -> Void = { [weak self] in self?.record($0) }
        Notes.perform(action, text: text, app: settings.notesApp, template: settings.notesURLTemplate, folder: settings.notesFolder, record: record) { [weak self] message in
            if let message {
                self?.panelHost.showHUD(message)
            }
        }
    }
}
