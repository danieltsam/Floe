//
//  ShellSnapshots.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import Foundation
import Synchronization

/// What the shell's suggestions read: the history, the programs on the PATH and a folder's entries,
/// each kept as a snapshot the search is answered from at once. The reads run off the main actor
/// behind the typing, and a snapshot that changed asks the launcher to look again.
final nonisolated class ShellSnapshots: Sendable {
    /// One store in the process: the search is answered from it, and its reads are its own.
    static let shared = ShellSnapshots()

    /// How many folders' answers are kept: a session that wanders holds only its last stops.
    static let keptFolders = 32

    private let lifetime: TimeInterval
    private let now: @Sendable () -> Date
    private let readHistory: @Sendable () -> [String]
    private let readPrograms: @Sendable () -> [String]
    private let readEntries: @Sendable (String) -> [String]

    /// The readers, the lifetime and the clock are given, so a test can hold a read or turn the
    /// time; the shared store reads the real history, the real PATH and the real folders.
    init(
        lifetime: TimeInterval = 2,
        now: @escaping @Sendable () -> Date = { Date() },
        readHistory: @escaping @Sendable () -> [String] = { ShellHistory.commands() },
        readPrograms: @escaping @Sendable () -> [String] = ShellSuggestions.programsOnPath,
        readEntries: @escaping @Sendable (String) -> [String] = ShellSuggestions.entriesOnDisk
    ) {
        self.lifetime = lifetime
        self.now = now
        self.readHistory = readHistory
        self.readPrograms = readPrograms
        self.readEntries = readEntries
    }

    private struct Answer: Sendable {
        var value: [String]
        var taken: Date
    }

    private let historyAnswer = Mutex(Answer(value: [], taken: Date.distantPast))
    private let programsAnswer = Mutex(Answer(value: [], taken: Date.distantPast))
    private let entryAnswers = Mutex<[String: Answer]>([:])
    /// What to do when a snapshot changed. One slot, held by the one process that runs the search.
    private let onChange = Mutex<(@MainActor () -> Void)?>(nil)
    /// The newest ask of each kind; an older ask's answer is dropped when it lands. The folders
    /// count their asks each on their own: a read of one folder is not made stale by another's.
    private let historyAsk = Mutex(0)
    private let programsAsk = Mutex(0)
    private let entryAsks = Mutex<[String: Int]>([:])
    /// The reads already on their way, so a stale answer does not start the same read twice:
    /// the one running is the one that lands.
    private let historyRead = Mutex(false)
    private let programsRead = Mutex(false)
    private let entryReads = Mutex<Set<String>>([])

    /// Says what to do when a snapshot changed. The launcher's model asks its search again.
    func whenChanged(_ action: @escaping @MainActor () -> Void) {
        onChange.withLock { $0 = action }
    }

    /// The commands in the history, as they were at the last read.
    func history() -> [String] {
        let stale = historyAnswer.withLock { now().timeIntervalSince($0.taken) >= lifetime }
        if stale, startRead(historyRead) {
            let ask = historyAsk.withLock { current in
                current += 1
                return current
            }
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let commands = self.readHistory()
                await self.landHistory(ask: ask, commands: commands)
                self.endRead(self.historyRead)
            }
        }
        return historyAnswer.withLock { $0.value }
    }

    /// The names on the PATH, from the one walk of it.
    func programs() -> [String] {
        let stale = programsAnswer.withLock { $0.value.isEmpty }
        if stale, startRead(programsRead) {
            let ask = programsAsk.withLock { current in
                current += 1
                return current
            }
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let names = self.readPrograms()
                await self.landPrograms(ask: ask, names: names)
                self.endRead(self.programsRead)
            }
        }
        return programsAnswer.withLock { $0.value }
    }

    /// A folder's entries, as they were at the last read. A folder never asked for is empty until its read lands.
    func entries(_ folder: String) -> [String] {
        let stale = entryAnswers.withLock { answers in
            guard let answer = answers[folder] else { return true }
            return now().timeIntervalSince(answer.taken) >= lifetime
        }
        if stale, let ask = startEntryRead(folder) {
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let listed = self.readEntries(folder)
                await self.landEntries(ask: ask, folder: folder, listed: listed)
                self.endEntryRead(folder)
            }
        }
        return entryAnswers.withLock { $0[folder]?.value ?? [] }
    }

    /// Claims a read of one kind, when none of it is on its way already. The ask that finds a read
    /// running waits for that one instead of starting another and throwing its answer out.
    private func startRead(_ running: borrowing Mutex<Bool>) -> Bool {
        running.withLock { isRunning in
            if isRunning {
                return false
            }
            isRunning = true
            return true
        }
    }

    private func endRead(_ running: borrowing Mutex<Bool>) {
        running.withLock { $0 = false }
    }

    /// Claims a folder's read and counts its ask, or nil when a read of the same folder is on its
    /// way already: the ask that finds one running waits for it instead of throwing its answer out.
    private func startEntryRead(_ folder: String) -> Int? {
        entryReads.withLock { running in
            if running.contains(folder) {
                return nil
            }
            running.insert(folder)
            return entryAsks.withLock { asks in
                asks[folder, default: 0] += 1
                return asks[folder]
            }
        }
    }

    private func endEntryRead(_ folder: String) {
        _ = entryReads.withLock { $0.remove(folder) }
    }

    /// Puts a finished read where it belongs, unless a newer ask superseded it. Freshness is renewed
    /// whichever way the read came out; only a different answer is told, so the search looks again.
    @MainActor
    private func landHistory(ask: Int, commands: [String]) {
        guard ask == historyAsk.withLock({ $0 }) else { return }
        let changed = historyAnswer.withLock { answer in
            let changed = answer.value != commands
            answer = Answer(value: commands, taken: now())
            return changed
        }
        if changed {
            tell()
        }
    }

    @MainActor
    private func landPrograms(ask: Int, names: [String]) {
        guard ask == programsAsk.withLock({ $0 }) else { return }
        let changed = programsAnswer.withLock { answer in
            let changed = answer.value != names
            answer = Answer(value: names, taken: now())
            return changed
        }
        if changed {
            tell()
        }
    }

    /// Puts a folder's finished listing where it belongs, unless a newer ask superseded it, renews its
    /// freshness either way, and lets go of the oldest answers when too many are held.
    @MainActor
    private func landEntries(ask: Int, folder: String, listed: [String]) {
        guard ask == entryAsks.withLock({ $0[folder] }) else { return }
        let changed = entryAnswers.withLock { answers in
            let changed = answers[folder]?.value != listed
            answers[folder] = Answer(value: listed, taken: now())
            while answers.count > Self.keptFolders, let oldest = answers.min(by: { $0.value.taken < $1.value.taken })?.key {
                answers.removeValue(forKey: oldest)
            }
            return changed
        }
        if changed {
            tell()
        }
    }

    /// A snapshot changed: the launcher is asked to look again, on the main actor.
    private func tell() {
        guard let action = onChange.withLock({ $0 }) else { return }
        Task { @MainActor in
            action()
        }
    }
}
