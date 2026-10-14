//
//  Model+CommandLinks.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import Foundation

/// A raycast://extensions/<owner>/<extension>/<command> link, which extensions open to start a command.
struct CommandLink {
    let extensionName: String
    let commandName: String
    /// Nil when the link carries none, so a command that takes arguments asks for them.
    let arguments: [String: Any]?

    /// Nil for every other raycast:// link: those name a feature of Raycast's own.
    init?(_ url: URL) {
        let names = url.pathComponents.filter { $0 != "/" }
        guard url.scheme?.lowercased() == "raycast", url.host() == "extensions", names.count == 3 else { return nil }
        extensionName = names[1]
        commandName = names[2]
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        let json = items?.first { $0.name == "arguments" }?.value
        arguments = json.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] }
    }
}

extension LauncherModel {
    /// Runs the command a link names when it is installed and enabled. Any other link is left to the system.
    func runCommandLink(_ url: URL) -> Bool {
        // The owner is not compared: an installed extension is known by its name alone.
        guard let link = CommandLink(url),
              let command = commands.first(where: { $0.extensionName == link.extensionName && $0.name == link.commandName })
        else { return false }
        // Running a menu-bar command that has its status item would take the item away.
        if command.mode != "menu-bar" || !isInMenuBar(command) {
            run(command, arguments: link.arguments)
        }
        return true
    }
}
