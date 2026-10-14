//
//  NoteDeskView.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import SwiftUI
import ThawUI

/// The notes of the folder the user chose: a list to search, and the note read as Markdown or written as text.
/// The bottom says which app the notes are kept in, since Floe keeps none itself.
struct NoteDeskView: View {
    @ObservedObject var desk: NoteDeskModel
    /// For the gear. Not observed: nothing here is drawn from it.
    let launcher: LauncherModel
    let focusToken: Int
    @FocusState private var isWriting: Bool

    var body: some View {
        PanelSections {
            SearchBar(placeholder: String(localized: "Search notes, or name a new one…", bundle: .floe), text: $desk.query, focusToken: focusToken) { EmptyView() }
        } content: {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            bottomBar
        }
        .onChange(of: desk.isEditing) { isWriting = desk.isEditing }
    }

    @ViewBuilder
    private var content: some View {
        if case let .elsewhere(app) = desk.place {
            ThawEmptyState(
                systemImage: "note.text",
                title: app.isEmpty ? "Choose a folder for your notes" : "Your notes are kept in \(app)",
                caption: "To read and write notes here, choose a folder of notes, such as an Obsidian vault, as the notes app in Settings."
            )
        } else if desk.notes.isEmpty {
            ThawEmptyState(systemImage: "note.text", title: "No notes in this folder yet", caption: "Press ⌘N to write the first.")
        } else if desk.filtered.isEmpty {
            ThawEmptyState(systemImage: "magnifyingglass", title: "No note has that name", caption: "Press ⌘N to make one.")
        } else {
            HStack(spacing: 0) {
                list(desk.filtered)
                    .frame(width: 230)
                Divider()
                note
            }
        }
    }

    private func list(_ notes: [DeskNote]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                        row(note, selected: index == desk.selection)
                            .onTapGesture { desk.select(index) }
                    }
                }
            }
            .contentMargins(.all, ThawSpacing.base, for: .scrollContent)
            .onChange(of: desk.selection) {
                if notes.indices.contains(desk.selection) {
                    proxy.scrollTo(notes[desk.selection].id)
                }
            }
        }
    }

    private func row(_ note: DeskNote, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: note.name)
                .lineLimit(1)
            Text(note.modified, format: .relative(presentation: .named))
                .font(ThawType.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .font(ThawType.body)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(RowBackground(selected: selected))
        .id(note.id)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var note: some View {
        if let notice = desk.notice {
            ThawEmptyState(systemImage: "doc.text", title: "\(notice)")
        } else if desk.isEditing {
            TextEditor(text: $desk.text)
                .font(.system(size: 13, design: .monospaced))
                .scrollContentBackground(.hidden)
                .focused($isWriting)
                .padding(10)
                .onAppear { isWriting = true }
        } else {
            ScrollView {
                MarkdownTextView(text: desk.text)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: ThawSpacing.row) {
            OpenSettingsButton(model: launcher)
            if let folder = desk.folder {
                Text(verbatim: NoteDesk.placeLabel(folder: folder, owner: desk.owner))
                    .font(ThawType.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(folder.path)
            }
            Spacer(minLength: 0)
            if desk.folder != nil {
                ShortcutHintButton(title: String(localized: "New Note", bundle: .floe)) { desk.makeNote() } hint: {
                    KeyCapView(text: "⌘N")
                }
            }
            if desk.selected != nil {
                ShortcutHintButton(title: openTitle) { desk.openInApp() } hint: {
                    KeyCapView(text: "⌘O")
                }
                ShortcutHintButton(title: desk.isEditing ? String(localized: "Done", bundle: .floe, comment: "A button that ends writing a note.") : String(localized: "Write", bundle: .floe, comment: "A verb on a button: start changing the note on screen.")) { desk.toggleEditing() } hint: {
                    KeyCapView(text: "⌘E")
                }
            }
        }
        .padding(.horizontal, ThawSpacing.inset)
        .padding(.vertical, ThawSpacing.row)
    }

    private var openTitle: String {
        if let owner = desk.owner {
            return String(localized: "Open in \(owner)", bundle: .floe, comment: "A button. The placeholder is the name of an app.")
        }
        return String(localized: "Open", bundle: .floe, comment: "A verb on a button: open the selected result.")
    }
}
