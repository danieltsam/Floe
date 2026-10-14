//
//  Model.swift
//  Project: Floe
//
//  Copyright (Floe) © 2026 René Jiménez
//  Licensed under the GNU AGPLv3

import AppKit
import ApplicationServices
import Combine

final class LauncherModel: ObservableObject {
    @Published var query = "" {
        didSet { typing.changed { [weak self] in self?.refresh() } }
    }

    let typing = TypingSettle()
    /// The text the results on screen answer. While typing is paced it trails `query`, and rows mark their matches by it.
    private(set) var searchedQuery = ""

    @Published private(set) var results: [RootResult] = [] {
        didSet {
            resultsVersion += 1
            rowSelection.reset()
            tellTheSelectedRow()
        }
    }

    @Published var selection = 0 {
        didSet { tellTheSelectedRow() }
    }

    /// Counts every new list of results, so the list view knows one from the next without comparing rows.
    private(set) var resultsVersion = 0
    let rowSelection = RowSelection()

    private func tellTheSelectedRow() {
        rowSelection.select(results.indices.contains(selection) ? results[selection].id : nil)
    }

    /// Runs extension commands and keeps the one on screen.
    let runner = ExtensionRunner()
    /// The setup form on screen, if any. What is typed into it is `setupForm`'s.
    @Published var setup: SetupRequest?
    /// Not published: typing in the form redraws the form only.
    let setupForm = SetupFormModel()
    /// Bumped whenever the panel is shown so the search field can take focus again.
    @Published var focusToken = 0
    /// The apps, commands, scripts, panes and hosts the search finds; the model refreshes when a part changes.
    let catalog: CatalogStore
    /// How a host's connection is opened. Tests replace it, so they open nothing.
    var sshConnector = SSHConnector.system
    /// The shortcuts of Apple's Shortcuts app and their runs. Nothing is read while the switch in Privacy is off.
    lazy var shortcutLibrary = AppleShortcutLibrary()

    /// True while the panel shows the file search instead of the root search.
    @Published var isSearchingFiles = false
    /// The file search's own state. Not published: its changes redraw its view only.
    lazy var fileSearch = FileSearchModel()

    /// True while the panel shows the menu bar item search instead of the root search.
    @Published var isSearchingMenuBar = false
    /// True while the panel shows the clipboard history instead of the root search.
    @Published var isShowingClipboardHistory = false
    /// The clipboard history view's own state. Not published: its changes redraw its view only.
    lazy var clipboardHistory = ClipboardHistoryModel(usage: usage)
    /// The notes of the user's folder, while the panel shows them instead of the root search.
    @Published var noteDesk: NoteDeskModel?
    /// The question on screen and its answer, while the panel shows them instead of the root search.
    @Published var askAI: AskAIModel?
    /// Answers the question. A test replaces it: the real thing reaches the chosen AI source.
    var askAIRequest: AskAIModel.Request = AskAIModel.live
    /// Whether an AI source can answer. The app delegate sets it; without one no Ask AI row is offered.
    var canAskAI: () -> Bool = { false }
    /// The menu bar item search's own state. Not published: its changes redraw its view only.
    lazy var menuBarSearch = MenuBarSearchModel(settings: settings)

    // The app delegate replaces these; the defaults keep the model usable without a window.
    var hidePanel: () -> Void = { /* no panel */ }
    var showPanel: () -> Void = { /* no panel */ }
    /// Set only in the resident; the foreground model executes these requests locally.
    var presentInPanelProcess: ((PanelRequest) -> Void)?
    var residentRequests: ((PanelPacket) -> Void)?
    var showHUD: (String) -> Void = { _ in
        // No HUD.
    }

    /// Opens the settings window, on a page when one is named.
    var openSettings: (SettingsPage?) -> Void = { _ in
        // No settings window.
    }

    /// Pops the Actions menu of the search that is on screen: root, files or menu bar items.
    var showActions: () -> Void = { /* set by the Actions button */ }

    /// The scope whose rows are on screen, when the query names one.
    var activeScope: ScopeMatch?
    /// True while a scope's rows are still on their way.
    @Published private(set) var isAwaitingResults = false
    /// Stands in for opening a scope's row. Tests set it: the real thing pastes and clicks outside the launcher.
    var scopeResultOpener: ((RootItem) -> Void)?
    private let scopes: [any SearchScope]
    private let scopeUpdates = SearchUpdates()
    /// The optional sources, and the rows they found for the ordinary search on screen.
    private let sources: [any SearchSource]
    private let sourceSearch = SourceSearch()
    lazy var definitionSearch = DefinitionSearch()

    let settings: AppSettings
    let isResident: Bool
    /// The apps the roles resolve to, kept until something they depend on changes.
    let resolvedApps: ResolvedApps
    private var cancellables: Set<AnyCancellable> = []
    var clipboardOpener = ClipboardOpener.system
    var linkOpener = LinkOpener.system
    let usage: UsageStore
    /// What the shell rows reach outside the launcher through. Tests replace its parts.
    var shell = ShellEnvironment()
    /// Where receipts are kept. Tests give one of their own.
    var receipts = ReceiptStore.shared
    var checkpointStore = CheckpointStore.shared
    var checkpointing = CheckpointEnvironment()
    var reminding = ReminderEnvironment()
    var scheduling = EventEnvironment()
    var timing = TimerEnvironment()
    var music = MusicEnvironment()
    let runningTimers = RunningTimers()
    /// The saved checkpoints, read when the launcher opens and when one is saved or deleted.
    var checkpoints: [Checkpoint] = []
    /// Where in the remembered searches the field stands, while the Up arrow walks back through them.
    var recalledQuery: Int?
    private var didAutorun = false
    private var pendingReset: DispatchWorkItem?
    private(set) var isPanelShown = false
    var commands: [ExtensionCommand] {
        CommandLookup.enabled(catalog.allCommands, disabledExtensions: settings.disabledExtensions, disabledCommands: settings.disabledCommands, enabledCommands: settings.enabledCommands)
    }

    /// Every command that may run on its own: a menu-bar command only once it was put in the menu bar.
    /// Controllers read this and filter by mode.
    var enabledCommands: [ExtensionCommand] {
        commands.filter { $0.mode != "menu-bar" || settings.menuBarCommands.contains($0.id) }
    }

    func isInMenuBar(_ command: ExtensionCommand) -> Bool {
        settings.menuBarCommands.contains(command.id)
    }

    /// Gives a menu-bar command its status item, or takes it away again.
    func toggleMenuBarCommand(_ command: ExtensionCommand) {
        if settings.menuBarCommands.remove(command.id) != nil {
            showHUD(String(localized: "Removed from Menu Bar", bundle: .floe))
        } else {
            settings.menuBarCommands.insert(command.id)
            showHUD(String(localized: "Added to Menu Bar", bundle: .floe))
        }
        refresh()
    }

    /// True when a command can run unattended: no missing required preferences or arguments.
    func canRunUnattended(_ command: ExtensionCommand) -> Bool {
        PreferenceStore.missingRequired(for: command).isEmpty
            && command.arguments.allSatisfy { !$0.required }
    }

    /// Construction never scans: `startCatalogLoading()` fills the catalog after subscribers are wired.
    /// The resident loads commands for hotkeys/background work, but never builds search state.
    init(
        scanner: any CatalogScanning = CatalogLoader(),
        settings: AppSettings = .shared,
        usage: UsageStore = .shared,
        snapshot: CatalogSnapshot? = nil,
        scopes: [any SearchScope]? = nil,
        sources: [any SearchSource]? = nil,
        isResident: Bool = false
    ) {
        self.isResident = isResident
        self.scopes = scopes ?? (isResident ? [] : RootSearch.standardScopes())
        self.sources = sources ?? (isResident ? [] : RootSearch.standardSources())
        self.settings = settings
        self.usage = usage
        catalog = CatalogStore(scanner: scanner, settings: settings, snapshot: snapshot)
        resolvedApps = ResolvedApps(settings: settings)
        catalog.onChange = { [weak self] in self?.catalogChanged($0) }
        connectRunner()
        guard !isResident else { return }
        connectModes()
        // Views read the catalog's loading state and the open command through the model, so their changes redraw it.
        catalog.$isLoading.removeDuplicates().dropFirst().map { _ in () }
            .merge(with: runner.$session.dropFirst().map { _ in () })
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        EmojiCatalog.preload()
        CalendarAgenda.shared.onChange = { [weak self] in self?.refresh() }
        resolvedApps.followChoices()
        refresh()
    }

    /// Recomputes foreground search results; the resident never constructs search-only sources.
    func refresh() {
        guard !isResident else { return }
        let started = Date()
        searchedQuery = query
        defer {
            if Date().timeIntervalSince(started) >= Log.slowSearch {
                Log.search.warning("Slow search: \(Log.milliseconds(since: started)) ms for \(query.count) characters, \(results.count) rows")
            }
        }
        var context = searchContext()
        // A source that is switched on also answers to its keyword, after the scopes that are always there.
        let enabled = RootSearch.enabled(sources, in: settings.searchSources)
        guard let match = RootSearch.scope(in: context, scopes: ClipboardApps.scopes(scopes, handler: settings.clipboardHandler, parked: settings.clipboardHistoryIsParked) + enabled) else {
            activeScope = nil
            scopeUpdates.cancel()
            selection = 0
            // The list is shown at once; a source's rows join it when they arrive.
            sourceSearch.search(context, sources: enabled) { [weak self] in self?.showSourceRows() }
            definitionSearch.search(context) { [weak self] in self?.showDefinitionRows() }
            context.definition = definitionSearch.definition
            isAwaitingResults = sourceSearch.isSearching || definitionSearch.isSearching
            results = RootSearch.results(for: context, sources: sourceSearch.rows)
            return
        }
        // A refresh that is not a new query, such as a rescan or a favorite, leaves a running scope alone.
        guard match.query != activeScope?.query else { return }
        sourceSearch.cancel()
        definitionSearch.cancel()
        activeScope = match
        selection = 0
        results = match.rows(match.scope.results(for: match.text, context: context))
        isAwaitingResults = scopeUpdates.follow(match.scope.updates(for: match.text, context: context)) { [weak self] items in
            self?.showScoped(match.rows(items))
        } finish: { [weak self] in
            self?.isAwaitingResults = false
        }
    }

    /// Rows that arrived after the query was typed. A selection the user moved stays on its row.
    private func showScoped(_ rows: [RootResult]) {
        let selected = selection == 0 ? nil : selectedRootItem?.id
        results = rows
        selection = selected.flatMap { id in rows.firstIndex { $0.id == id } } ?? min(selection, max(rows.count - 1, 0))
    }

    /// A source's rows arrived below the ranked ones. The selection stays on the row it was on.
    func showSourceRows() {
        let selected = selectedRootItem?.id
        isAwaitingResults = sourceSearch.isSearching || definitionSearch.isSearching
        results = RootSearch.results(for: searchContext(), sources: sourceSearch.rows)
        selection = selected.flatMap { id in results.firstIndex { $0.id == id } } ?? min(selection, max(results.count - 1, 0))
    }

    func alias(for item: RootItem) -> String? {
        RootSearch.alias(for: item, aliases: settings.aliases)
    }

    func isFavorite(_ item: RootItem) -> Bool {
        settings.favorites.contains(item.id)
    }

    func toggleFavorite(_ item: RootItem) {
        if case .searchFiles = item {
            // The fallback row names a query, not a thing: it has no favorites entry.
            return
        }
        if item.isScopeResult {
            return
        }
        if case .askAI = item {
            return
        }
        if let index = settings.favorites.firstIndex(of: item.id) {
            settings.favorites.remove(at: index)
            showHUD(String(localized: "Removed from Favorites", bundle: .floe))
        } else {
            settings.favorites.append(item.id)
            showHUD(String(localized: "Added to Favorites", bundle: .floe))
        }
        refresh()
    }

    /// Opens an app, or hides it if it's already in front, like a per-app hotkey in Thaw.
    func toggleApp(_ app: AppEntry) {
        usage.recordUse(of: RootItem.app(app).id)
        if let running = NSWorkspace.shared.frontmostApplication, running.bundleURL?.standardizedFileURL == app.url.standardizedFileURL {
            running.hide()
        } else {
            NSWorkspace.shared.openWithoutWaiting(app.url)
        }
    }

    /// `FLOE_AUTORUN=extension/command` opens a command at startup, for screenshots and debugging.
    /// It waits for the command load that is current when it runs and attempts the command once;
    /// later rescans never rerun it.
    func autorun(
        target: String? = ProcessInfo.processInfo.environment["FLOE_AUTORUN"],
        launch: ((ExtensionCommand) -> Void)? = nil
    ) {
        Task { @MainActor [weak self] in
            await self?.catalog.waitForCommands()
            guard let self, !didAutorun else { return }
            didAutorun = true
            guard let target, let command = commands.first(where: { $0.id == target }) else { return }
            if let launch {
                launch(command)
            } else {
                runner.run(command)
            }
        }
    }

    /// Executes the selected root result, including routing Settings rows to their requested page.
    func activate(_ item: RootItem) {
        if case let .emoji(entry) = item {
            pasteEmojiResult(entry)
            return
        }
        if item.isScopeResult {
            // Found just now and gone next time: opening one records no frecency entry.
            (scopeResultOpener ?? openScopeResult)(item)
            return
        }
        if case let .askAI(question) = item {
            // Nothing about a question is kept: no usage record either.
            openAskAI(question)
            return
        }
        if case .searchFiles = item {
            // A transient row for the query text: opening it records no frecency entry.
        } else {
            usage.recordUse(of: item.id)
        }
        rememberQuery()
        switch item {
        case let .app(app):
            NSWorkspace.shared.openWithoutWaiting(app.url)
            hidePanel()
            reset()
        case let .command(command):
            runner.run(command)
        case let .script(script):
            let text = script.argumentsText(in: query) ?? ""
            run(script, argumentStrings: ScriptRunner.splitArguments(text))
        case .menuBarSearch:
            openMenuBarSearch()
        case .emojiSearch:
            query = EmojiSearchProvider.prefix
            focusToken += 1
        case .clipboardHistory, .clipboardApp:
            openClipboardHistory()
        case .fileSearch:
            openFileSearch(with: query)
        case let .searchFiles(searchQuery):
            openFileSearch(with: searchQuery)
        case .settings, .extensionStore:
            hidePanel()
            openSettings(item.settingsPage)
        case let .quicklink(link, queryText, _, _):
            if let destination = url(for: link, query: queryText) {
                openLink(destination)
            }
            hidePanel()
            reset()
        case let .system(command):
            runSystemCommand(command)
        case let .note(action, text):
            hidePanel()
            reset()
            writeNote(action, text: text)
        case let .finderSelection(role, app):
            openFinderSelection(in: role, app: app)
        case let .thaw(action):
            hidePanel()
            reset()
            if !Thaw.perform(action) {
                showHUD(String(localized: "Thaw isn't installed", bundle: .floe))
            }
        case let .sshHost(host, terminal):
            hidePanel()
            reset()
            SSHConnection.connect(to: host, terminal: terminal, using: sshConnector) { [weak self] in self?.showHUD($0) }
        case let .shortcut(shortcut):
            run(shortcut)
        case let .settingsPane(pane):
            if let url = pane.url {
                NSWorkspace.shared.openWithoutWaiting(url)
            }
            hidePanel()
            reset()
        case let .snippet(snippet):
            runner.paste(text: SnippetStore.shared.expanded(snippet))
        case let .event(event):
            if let destination = event.meetingURL ?? event.calendarURL {
                openLink(destination)
            }
            hidePanel()
            reset()
        case let .calculator(_, result, error, _):
            copyCalculation(result, error: error)
        default:
            // A scope's rows were opened before the switch. What is left is a row that came later.
            openLater(item)
        }
    }

    /// Risky commands ask first; the panel goes away before anything runs.
    func runSystemCommand(_ command: SystemCommand) {
        hidePanel()
        reset()
        if let question = command.confirmation {
            guard Confirm.destructive(command.title, detail: question, button: command.title) else { return }
        }
        if let flip = command.flip {
            showHUD(flip())
            return
        }
        if let control = command.music {
            controlMusic(control)
            return
        }
        command.perform()
    }

    /// Copies an emoji without pasting; ⌘↵ on a result.
    func copyEmojiResult(_ entry: EmojiResult) {
        usage.recordUse(of: entry.id)
        NSPasteboard.general.copy(entry.character)
        showHUD(String(localized: "Copied \(entry.character)", bundle: .floe, comment: "Shown briefly after copying. The placeholder is what was copied, such as a file name."))
    }

    /// Pastes an emoji into the frontmost app: onto the clipboard plus a ⌘V once the panel is
    /// gone, when Accessibility access is granted; otherwise the copy plus a "Copied" HUD.
    func pasteEmojiResult(_ entry: EmojiResult) {
        usage.recordUse(of: entry.id)
        NSPasteboard.general.copy(entry.character)
        guard AXIsProcessTrusted() else {
            showHUD(String(localized: "Copied", bundle: .floe, comment: "Shown briefly after something was put on the clipboard."))
            return
        }
        hidePanel()
        reset()
        // Pressed once the panel is gone, so the keystroke lands in the app the user came from.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            ClipboardHistoryStore.simulatePaste()
        }
    }

    /// Runs a script command with the given argv. Arguments come from the text typed after its
    /// title; output follows its mode: a window for fullOutput, a HUD for compact and inline,
    /// nothing for silent. Failures show a HUD with the last stderr line.
    func run(_ script: ScriptCommand, argumentStrings: [String] = []) {
        if script.needsConfirmation {
            let alert = NSAlert()
            alert.messageText = String(localized: "Run \(script.title)?", bundle: .floe, comment: "The placeholder is the name of a script.")
            alert.informativeText = script.displayPackage
            alert.addButton(withTitle: String(localized: "Run", bundle: .floe, comment: "A verb on a button: run the shortcut or script."))
            alert.addButton(withTitle: String(localized: "Cancel", bundle: .floe))
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        usage.recordUse(of: RootItem.script(script).id)
        hidePanel()
        reset()
        PanelWork.perform { [weak self] in
            let result: ShellResult
            do {
                result = try await ScriptRunner.run(script, arguments: argumentStrings)
            } catch {
                await MainActor.run { [weak self] in
                    self?.showHUD(String(localized: "\(script.title) failed: \(error.localizedDescription)", bundle: .floe, comment: "The first placeholder is the name of a script, the second is the reason."))
                }
                return
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                guard result.succeeded else {
                    let line = ScriptRunner.lastLine(result.errorOutput) ?? ScriptRunner.lastLine(result.output)
                        ?? String(localized: "exit code \(result.status)", bundle: .floe, comment: "The reason a script failed, when it printed nothing. The placeholder is a number.")
                    showHUD(String(localized: "\(script.title) failed: \(line)", bundle: .floe, comment: "The first placeholder is the name of a script, the second is the reason."))
                    return
                }
                switch script.mode {
                case .silent:
                    break
                case .inline, .compact:
                    let line = ScriptRunner.lastLine(result.output) ?? String(localized: "Done (script finished)", defaultValue: "Done", bundle: .floe, comment: "Shown briefly when a script finished and printed nothing.")
                    showHUD(line)
                case .fullOutput:
                    ScriptOutputWindow.show(title: script.title, output: result.trimmedOutput)
                }
            }
        }
    }

    /// Runs a command, first asking for missing required preferences and then for its arguments.
    /// The panel closed. The open command survives for the configured delay, so reopening resumes it.
    func panelDidHide() {
        isPanelShown = false
        pendingReset?.cancel()
        let delay = settings.popToRootDelay
        guard delay > 0, runner.session != nil || setup != nil else {
            reset()
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.reset() }
        pendingReset = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay), execute: work)
    }

    /// Whether the panel is hidden with its command kept for the user to come back to.
    var isWaitingToResume: Bool {
        pendingReset != nil
    }

    /// Cancels the deferred reset. What is read again for the search waits for panelDidShow.
    func panelWillShow() {
        isPanelShown = true
        pendingReset?.cancel()
        pendingReset = nil
    }

    /// Back to the root search, ending any open command.
    func reset() {
        guard !isResident else { return }
        pendingReset?.cancel()
        pendingReset = nil
        runner.endOpenCommand()
        setup = nil
        isSearchingMenuBar = false
        isShowingClipboardHistory = false
        isSearchingFiles = false
        fileSearch.cancel()
        closeNoteDesk()
        closeAskAI()
        recalledQuery = nil
        query = ""
    }
}
