//
//  BuiltInCommandsSection.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import SwiftUI
import ThawUI

/// Floe's own commands, each on one line with the alias and hotkey it answers to, as an extension's commands are.
struct BuiltInCommandsSection: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ThawSection("Built-in Commands") {
            ForEach(LauncherModel.hotkeyViews, id: \.id) { item in
                row(for: item)
            }
            DisclosureGroup("System Commands") {
                ForEach(SystemCommand.allCases) { command in
                    row(for: .system(command))
                }
            }
            ThawSupportNotice()
        }
    }

    @ViewBuilder
    private func row(for item: RootItem) -> some View {
        if let key = item.settingsKey {
            HStack(spacing: ThawSpacing.compact) {
                Text(item.title)
                    .lineLimit(1)
                Spacer()
                TextField(
                    "Alias",
                    text: Binding(get: { settings.aliases[key] ?? "" }, set: { settings.aliases[key] = $0.isEmpty ? nil : $0 }),
                    prompt: Text("Alias")
                )
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                HotkeyRecorder(
                    keyCombination: Binding(get: { settings.commandHotkeys[key] }, set: { settings.commandHotkeys[key] = $0 }),
                    onRecordingChange: { settings.isRecordingHotkey = $0 },
                    label: { Text("Hotkey") }
                )
                .labelsHidden()
                .fixedSize()
            }
        }
    }
}
