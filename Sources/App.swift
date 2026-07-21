import AppKit
import ApplicationServices
import Network

// ---------------------------------------------------------------------------
// Painel/botão que aceitam interação sem ativar o app
// ---------------------------------------------------------------------------

final class BubblePanel: NSPanel {
    var onKey: ((NSEvent) -> Bool)?
    override var canBecomeKey: Bool { true }
    override func keyDown(with event: NSEvent) {
        if onKey?(event) == true { return }
        super.keyDown(with: event)
    }
}

final class FirstClickButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// ---------------------------------------------------------------------------
// App
// ---------------------------------------------------------------------------

struct SessionInfo {
    var state: PetState
    var at: Date
    var project: String?
    var workingSince: Date?
}

struct CrabyConfig: Codable {
    var ntfyTopic: String?
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var window: NSWindow!
    var petView: PetView!
    var statusItem: NSStatusItem!
    var server: ControlServer?

    var state: PetState = .idle
    var frameIndex = 0
    var animTimer: Timer?
    var maintenanceTimer: Timer?
    var barImageCache: [String: NSImage] = [:]
    var floatingVisible = true

    // estado por sessão do Claude Code (multi-sessão)
    var sessions: [String: SessionInfo] = [:]

    // fila de pedidos de permissão/pergunta (conn nil = balão informativo local)
    var askQueue: [(payload: AskPayload, conn: NWConnection?)] = []
    var currentAsk: (payload: AskPayload, conn: NWConnection?)?
    var bubbleWindow: NSWindow?
    var inputField: NSTextField?
    var askTimeout: DispatchWorkItem?

    var stats: StatsStore!
    var config = CrabyConfig()
    var authToken = ""

    // personalidade: manias do ócio, sono, atualização
    var quirk: [[String]] = []
    var quirkIndex = 0
    var lastEventAt = Date()
    var availableUpdate: String?
    var updateTimer: Timer?
    let appVersion = "1.3.0"

    var appSupportDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Craby")
    }

    var soundsEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundsEnabled") as? Bool ?? true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? FileManager.default.createDirectory(
            at: appSupportDir, withIntermediateDirectories: true)
        stats = StatsStore(url: appSupportDir.appendingPathComponent("stats.json"))
        authToken = loadOrCreateToken()
        loadConfig()
        loadCustomSprites(from: appSupportDir.appendingPathComponent("sprites.json"))

        let width = CGFloat(gridCols) * pixelSize
        let height = CGFloat(gridRows) * pixelSize

        window = NSWindow(
            contentRect: initialFrame(width: width, height: height),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        // canJoinAllSpaces: existe em todos os desktops virtuais
        // fullScreenAuxiliary: aparece também sobre apps em tela cheia
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isMovableByWindowBackground = false

        petView = PetView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        petView.onAcknowledge = { [weak self] in self?.petClicked() }
        petView.onMoved = { [weak self] in self?.savePosition() }
        window.contentView = petView
        window.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.window.setFrame(
                self.initialFrame(width: width, height: height), display: true)
        }

        setupStatusItem()
        applyState(.idle)

        // reavalia sessões periodicamente (comemoração expira, sessões mortas somem)
        // e dá chance das manias do ócio acontecerem
        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) {
            [weak self] _ in
            self?.recomputeDisplayed()
            self?.maybeQuirk()
        }

        do {
            server = try ControlServer(
                port: 4923,
                authToken: authToken,
                onCommand: { [weak self] command, query in
                    guard let self else { return nil }
                    if command == "quit" { NSApp.terminate(nil); return nil }
                    if command == "status" { return self.statusJSON() }
                    if command.hasPrefix("answer/") {
                        self.answerCurrentAsk(String(command.dropFirst("answer/".count)))
                        return nil
                    }
                    if let newState = PetState(rawValue: command) {
                        self.sessionEvent(
                            newState,
                            session: query["session"] ?? "default",
                            project: query["project"])
                    }
                    return nil
                },
                onAsk: { [weak self] payload, conn in
                    guard let self else { return }
                    self.askQueue.append((payload, conn))
                    if self.currentAsk == nil { self.showNextAsk() }
                }
            )
        } catch {
            NSLog("craby: falha ao abrir porta 4923: \(error)")
        }

        // primeira execução: Craby se apresenta
        if !UserDefaults.standard.bool(forKey: "onboarded") {
            UserDefaults.standard.set(true, forKey: "onboarded")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self else { return }
                self.askQueue.append((
                    AskPayload(
                        title: L.welcomeTitle, detail: L.welcomeDetail,
                        urgent: false, options: [L.welcomeOk], input: nil),
                    nil))
                if self.currentAsk == nil { self.showNextAsk() }
            }
        }

        checkForUpdates()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) {
            [weak self] _ in self?.checkForUpdates()
        }
    }

    // ------------------------------------------------------------------
    // Atualizações: consulta o último release no GitHub (diário)
    // ------------------------------------------------------------------

    func checkForUpdates() {
        guard let url = URL(
            string: "https://api.github.com/repos/duperez/crab-companion/releases/latest")
        else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String
            else { return }
            let remote = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            if Self.isVersion(remote, newerThan: self.appVersion) {
                DispatchQueue.main.async { self.availableUpdate = remote }
            }
        }.resume()
    }

    static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let pa = a.split(separator: ".").compactMap { Int($0) }
        let pb = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    @objc func openReleases() {
        NSWorkspace.shared.open(
            URL(string: "https://github.com/duperez/crab-companion/releases")!)
    }

    @objc func openHomepage() {
        NSWorkspace.shared.open(URL(string: "https://duperez.github.io/crab-companion/")!)
    }

    // GET /status: visão de dentro do Craby (debug e integrações)
    func statusJSON() -> String {
        let sessionList = sessions.map { key, info in
            [
                "session": key,
                "project": info.project ?? "",
                "state": info.state.rawValue,
            ]
        }
        let payload: [String: Any] = [
            "version": appVersion,
            "displayed": state.rawValue,
            "level": stats.level.number,
            "totalTasks": stats.data.totalTasks,
            "sessions": sessionList,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8)
        else { return "{}" }
        return json
    }

    // ------------------------------------------------------------------
    // Token e configuração
    // ------------------------------------------------------------------

    private func loadOrCreateToken() -> String {
        let url = appSupportDir.appendingPathComponent("token")
        if let existing = try? String(contentsOf: url, encoding: .utf8) {
            let token = existing.trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty { return token }
        }
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        try? token.write(to: url, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: url.path)
        return token
    }

    private func loadConfig() {
        let url = appSupportDir.appendingPathComponent("config.json")
        if let raw = try? Data(contentsOf: url),
           let loaded = try? JSONDecoder().decode(CrabyConfig.self, from: raw) {
            config = loaded
        }
    }

    // ------------------------------------------------------------------
    // Posição: arrastável, persistida, com fallback pro canto padrão
    // ------------------------------------------------------------------

    func defaultFrame(width: CGFloat, height: CGFloat) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let area = screen.visibleFrame
        let margin: CGFloat = 12
        return NSRect(
            x: area.maxX - margin - bubbleWidth / 2 - width / 2,
            y: area.maxY - height - margin,
            width: width, height: height
        )
    }

    func initialFrame(width: CGFloat, height: CGFloat) -> NSRect {
        if let saved = UserDefaults.standard.array(forKey: "petOrigin") as? [Double],
           saved.count == 2 {
            let rect = NSRect(x: saved[0], y: saved[1], width: width, height: height)
            // só usa a posição salva se ela ainda estiver em alguma tela
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(rect) }) {
                return rect
            }
        }
        return defaultFrame(width: width, height: height)
    }

    func savePosition() {
        let origin = window.frame.origin
        UserDefaults.standard.set([origin.x, origin.y], forKey: "petOrigin")
    }

    @objc func resetPosition() {
        UserDefaults.standard.removeObject(forKey: "petOrigin")
        let size = window.frame.size
        window.setFrame(defaultFrame(width: size.width, height: size.height), display: true)
    }

    // ------------------------------------------------------------------
    // Menu da barra (reconstruído a cada abertura, com stats e eventos)
    // ------------------------------------------------------------------

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        let lvl = stats.level
        let header = NSMenuItem(
            title: L.levelLine(level: lvl.number, name: lvl.name, total: stats.data.totalTasks),
            action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let day = stats.today
        let todayItem = NSMenuItem(
            title: L.todayLine(
                tasks: day.tasks, projects: day.projects.count, workSeconds: day.workSeconds),
            action: nil, keyEquivalent: "")
        todayItem.isEnabled = false
        menu.addItem(todayItem)

        let streak = stats.streakDays
        if streak >= 2 {
            let streakItem = NSMenuItem(title: L.streak(streak), action: nil, keyEquivalent: "")
            streakItem.isEnabled = false
            menu.addItem(streakItem)
        }

        let eventsItem = NSMenuItem(title: L.recentEvents, action: nil, keyEquivalent: "")
        let eventsMenu = NSMenu()
        let events = stats.recentEvents()
        if events.isEmpty {
            let none = NSMenuItem(title: L.noEvents, action: nil, keyEquivalent: "")
            none.isEnabled = false
            eventsMenu.addItem(none)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            for event in events {
                let kind: String
                switch event.kind {
                case "done": kind = L.stateLabel(.done)
                case "level": kind = L.levelUp
                default: kind = L.stateLabel(.attention)
                }
                // clicar num evento foca a janela daquele projeto
                let item = NSMenuItem(
                    title: "\(formatter.string(from: event.ts)) · \(event.project) · \(kind)",
                    action: #selector(eventClicked(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = event.project
                eventsMenu.addItem(item)
            }
        }
        eventsItem.submenu = eventsMenu
        menu.addItem(eventsItem)
        menu.addItem(NSMenuItem.separator())

        let toggle = NSMenuItem(
            title: floatingVisible ? L.collapseToBar : L.showFloating,
            action: #selector(toggleFloating), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)

        let sounds = NSMenuItem(title: L.sounds, action: #selector(toggleSounds), keyEquivalent: "")
        sounds.target = self
        sounds.state = soundsEnabled ? .on : .off
        menu.addItem(sounds)

        let reset = NSMenuItem(
            title: L.resetPosition, action: #selector(resetPosition), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)

        let remote = NSMenuItem(
            title: (config.ntfyTopic?.isEmpty == false) ? L.remoteOn : L.remoteOff,
            action: nil, keyEquivalent: "")
        remote.isEnabled = false
        menu.addItem(remote)

        if let update = availableUpdate {
            let item = NSMenuItem(
                title: "🆕 " + L.updateAvailable(update),
                action: #selector(openReleases), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }

        let about = NSMenuItem(
            title: L.about, action: #selector(openHomepage), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(
            title: L.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc func eventClicked(_ sender: NSMenuItem) {
        guard let project = sender.representedObject as? String, project != "Craby",
              project != "?"
        else { return }
        focusSession(project: project)
    }

    @objc func toggleFloating() {
        floatingVisible.toggle()
        if floatingVisible {
            window.orderFrontRegardless()
        } else {
            window.orderOut(nil)
        }
    }

    @objc func toggleSounds() {
        UserDefaults.standard.set(!soundsEnabled, forKey: "soundsEnabled")
    }

    func playSound(for newState: PetState) {
        guard soundsEnabled else { return }
        switch newState {
        case .done: NSSound(named: "Glass")?.play()
        case .attention: NSSound(named: "Ping")?.play()
        default: break
        }
    }

    // ------------------------------------------------------------------
    // Modo ausente: se ninguém mexe no Mac há 2min e o Claude precisa de
    // você, avisa no celular via ntfy (se configurado em config.json)
    // ------------------------------------------------------------------

    func secondsSinceLastInput() -> Double {
        let types: [CGEventType] = [.keyDown, .mouseMoved, .leftMouseDown, .scrollWheel]
        return types.map {
            CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: $0)
        }.min() ?? 0
    }

    func maybeNotifyPhone(project: String?) {
        guard let topic = config.ntfyTopic, !topic.isEmpty,
              secondsSinceLastInput() > 120,
              let url = URL(string: "https://ntfy.sh/\(topic)")
        else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("crab", forHTTPHeaderField: "X-Tags")
        request.setValue("Craby", forHTTPHeaderField: "X-Title")
        let proj = project.map { "\($0): " } ?? ""
        request.httpBody = "🦀 \(proj)\(L.needsYouPush)".data(using: .utf8)
        URLSession.shared.dataTask(with: request).resume()
    }

    // ------------------------------------------------------------------
    // Multi-sessão: cada sessão tem um estado; o pet exibe o de maior prioridade
    // ------------------------------------------------------------------

    func sessionEvent(_ newState: PetState, session: String, project: String? = nil) {
        let now = Date()
        lastEventAt = now // qualquer evento acorda o Craby
        let existing = sessions[session]
        let proj = project ?? existing?.project
        var workingSince = existing?.workingSince

        if newState == .working {
            if existing?.state != .working { workingSince = now }
        } else {
            if existing?.state == .working, let since = workingSince {
                stats.addWork(project: proj ?? "?", seconds: now.timeIntervalSince(since))
            }
            workingSince = nil
        }
        if newState == .done {
            let levelBefore = stats.level.number
            stats.recordDone(project: proj ?? "?")
            if stats.level.number > levelBefore { celebrateLevelUp() }
        }
        if newState == .attention {
            stats.recordAttention(project: proj ?? "?")
            maybeNotifyPhone(project: proj)
        }

        sessions[session] = SessionInfo(
            state: newState, at: now, project: proj, workingSince: workingSince)
        recomputeDisplayed()
    }

    // clique no pet: se alguém precisa de você, foca a janela daquela sessão;
    // e reconhece só os AVISOS (attention/done) — trabalho em andamento continua
    func petClicked() {
        if let needy = sessions.values.first(where: { $0.state == .attention }) {
            focusSession(project: needy.project)
        }
        for (key, info) in sessions where info.state == .attention || info.state == .done {
            sessions[key]?.state = .idle
        }
        recomputeDisplayed()
    }

    func recomputeDisplayed() {
        let now = Date()
        // sessões sem eventos há 4h saem do placar; "done" vira idle após 30s
        sessions = sessions.filter { now.timeIntervalSince($0.value.at) < 4 * 3600 }
        for (key, info) in sessions where info.state == .done {
            if now.timeIntervalSince(info.at) > 30 { sessions[key]?.state = .idle }
        }
        // trabalho sem batimento (hook PostToolUse) há 10min = sessão morta
        for (key, info) in sessions where info.state == .working {
            if now.timeIntervalSince(info.at) > 600 { sessions[key]?.state = .idle }
        }
        var displayed = sessions.values.map(\.state).max(by: { $0.priority < $1.priority })
            ?? .idle
        // tudo quieto há 10min? Craby dorme (qualquer evento o acorda)
        if displayed == .idle, now.timeIntervalSince(lastEventAt) > 600 {
            displayed = .sleeping
        }
        updateTooltip()
        if displayed != state {
            playSound(for: displayed)
            applyState(displayed)
        } else {
            render() // pontinhos de sessões podem ter mudado
        }
    }

    private func updateTooltip() {
        let active = sessions.filter { $0.value.state != .idle }
        if active.isEmpty {
            petView.toolTip = L.allCalm
            return
        }
        let now = Date()
        petView.toolTip = active.values
            .map { info -> String in
                let name = info.project ?? L.sessionFallback
                if info.state == .working, let since = info.workingSince {
                    let minutes = max(0, Int(now.timeIntervalSince(since) / 60))
                    return "\(name): \(L.workingFor(minutes))"
                }
                return "\(name): \(L.stateLabel(info.state))"
            }
            .sorted()
            .joined(separator: "\n")
    }

    private var workingCount: Int {
        sessions.values.filter { $0.state == .working }.count
    }

    // pontinhos brancos no alto à esquerda: 1 por sessão trabalhando (quando > 1)
    private func overlayBadges(_ grid: [String]) -> [String] {
        let count = workingCount
        guard count > 1 else { return grid }
        var g = grid
        var row = Array(g[0])
        for i in 0..<min(count, 4) { row[i * 2] = "W" }
        g[0] = String(row)
        return g
    }

    // gota de esforço: aparece após 1min contínuo de trabalho
    private var isSweating: Bool {
        guard state == .working,
              let oldest = sessions.values.compactMap({ $0.workingSince }).min()
        else { return false }
        return Date().timeIntervalSince(oldest) > 60
    }

    private func overlaySweat(_ grid: [String]) -> [String] {
        guard isSweating else { return grid }
        var g = grid
        var row = Array(g[2])
        row[12] = "C"
        g[2] = String(row)
        return g
    }

    // ------------------------------------------------------------------
    // Personalidade: manias do ócio e comemoração de level-up
    // ------------------------------------------------------------------

    func startQuirk(_ frames: [[String]]) {
        quirk = frames
        quirkIndex = 0
        render()
    }

    func maybeQuirk() {
        guard state == .idle, quirk.isEmpty, currentAsk == nil,
              Int.random(in: 0..<6) == 0,
              let chosen = idleQuirks.randomElement()
        else { return }
        startQuirk(chosen)
    }

    func celebrateLevelUp() {
        stats.recordLevelUp()
        if soundsEnabled { NSSound(named: "Funk")?.play() }
        startQuirk(levelUpFrames + levelUpFrames)
    }

    // ------------------------------------------------------------------
    // Foco: tenta erguer a janela cujo título contém o nome do projeto
    // (requer permissão de Acessibilidade; sem ela, só ativa o app)
    // ------------------------------------------------------------------

    func focusSession(project: String?) {
        guard let claudeApp = ["Claude", "Terminal", "iTerm2"].lazy.compactMap({ name in
            NSWorkspace.shared.runningApplications.first { $0.localizedName == name }
        }).first else { return }

        if let project, AXIsProcessTrusted() {
            let ax = AXUIElementCreateApplication(claudeApp.processIdentifier)
            var value: CFTypeRef?
            AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &value)
            if let windows = value as? [AXUIElement] {
                for w in windows {
                    var t: CFTypeRef?
                    AXUIElementCopyAttributeValue(w, kAXTitleAttribute as CFString, &t)
                    if let title = t as? String,
                       title.localizedCaseInsensitiveContains(project) {
                        AXUIElementPerformAction(w, kAXRaiseAction as CFString)
                        break
                    }
                }
            }
        } else if project != nil {
            // pede a permissão uma única vez; cai no fallback enquanto isso
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            _ = AXIsProcessTrustedWithOptions(opts as CFDictionary)
        }
        claudeApp.activate()
    }

    func focusClaudeApp() { focusSession(project: nil) }

    // ------------------------------------------------------------------
    // Balão de pergunta
    // ------------------------------------------------------------------

    func showNextAsk() {
        guard currentAsk == nil, !askQueue.isEmpty else { return }
        currentAsk = askQueue.removeFirst()

        // balões informativos locais (conn nil) não mexem no placar nem nas stats
        if currentAsk!.conn != nil {
            // extrai "[projeto]" do título, se houver, para o registro de eventos
            let title = currentAsk!.payload.title
            var project: String?
            if let open = title.firstIndex(of: "["), let close = title.firstIndex(of: "]"),
               open < close {
                project = String(title[title.index(after: open)..<close])
            }
            sessionEvent(.attention, session: "ask", project: project)
        }
        showBubble(for: currentAsk!.payload)

        // se ninguém interagir, devolve "ask" -> prompt normal no terminal
        let seconds: Double = currentAsk!.payload.input == true ? 90 : 45
        let task = DispatchWorkItem { [weak self] in self?.answerCurrentAsk("ask") }
        askTimeout = task
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: task)
    }

    func answerCurrentAsk(_ answer: String) {
        guard let current = currentAsk else { return }
        var valid = ["allow", "deny", "ask"].contains(answer)
        if answer.hasPrefix("opt:"), let i = Int(answer.dropFirst(4)),
           let options = current.payload.options, (0..<options.count).contains(i) {
            valid = true
        }
        if answer.hasPrefix("txt:"), current.payload.input == true {
            valid = true
        }
        guard valid else { return }
        askTimeout?.cancel()
        askTimeout = nil
        if let conn = current.conn {
            ControlServer.respond(conn, body: answer)
        }
        bubbleWindow?.orderOut(nil)
        bubbleWindow = nil
        inputField = nil
        currentAsk = nil
        if current.conn != nil {
            sessionEvent(.working, session: "ask")
        }
        showNextAsk()
    }

    func showBubble(for ask: AskPayload) {
        let w = bubbleWidth
        let isQuestion = ask.options != nil
        let isInput = ask.input == true
        let optionCount = ask.options?.count ?? 0
        let h: CGFloat
        if isInput {
            h = 10 + 16 + 4 + 46 + 6 + 26 + 6 + 26 + 10
        } else if isQuestion {
            h = 10 + 16 + 4 + 46 + 6 + CGFloat(optionCount) * 30 + 26 + 10
        } else {
            h = bubbleHeight
        }
        let petFrame = window.frame
        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let area = screen.visibleFrame
        // abaixo do pet, centralizado; se não couber, abre acima
        var x = petFrame.midX - w / 2
        x = max(area.minX + 8, min(x, area.maxX - w - 8))
        var y = petFrame.minY - h - 8
        if y < area.minY + 8 { y = petFrame.maxY + 8 }

        let bubble = BubblePanel(
            contentRect: NSRect(x: x, y: y, width: w, height: h),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        bubble.isOpaque = false
        bubble.backgroundColor = .clear
        bubble.hasShadow = true
        bubble.level = .floating
        bubble.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        bubble.onKey = { [weak self] event in self?.handleBubbleKey(event) ?? false }

        let container = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 0.97).cgColor
        container.layer?.cornerRadius = 10
        container.layer?.borderWidth = 2
        container.layer?.borderColor =
            (ask.urgent ? NSColor.systemRed : NSColor.systemYellow).cgColor

        // badge da fila: avisa quantos pedidos aguardam atrás deste
        var titleText = ask.title
        if !askQueue.isEmpty {
            titleText += "  (+\(askQueue.count) \(L.queueSuffix))"
        }
        let title = NSTextField(labelWithString: titleText)
        title.font = .boldSystemFont(ofSize: 11)
        title.textColor = .white
        title.lineBreakMode = .byTruncatingTail
        title.frame = NSRect(x: 12, y: h - 26, width: w - 24, height: 16)
        container.addSubview(title)

        let detail = NSTextField(wrappingLabelWithString: ask.detail)
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = NSColor(calibratedWhite: 0.8, alpha: 1.0)
        detail.maximumNumberOfLines = (isQuestion || isInput) ? 3 : 2
        detail.lineBreakMode = .byTruncatingTail
        let detailHeight: CGFloat = (isQuestion || isInput) ? 46 : 32
        detail.frame = NSRect(x: 12, y: h - 30 - detailHeight, width: w - 24, height: detailHeight)
        container.addSubview(detail)

        if isInput {
            let field = NSTextField(frame: NSRect(x: 12, y: 42, width: w - 24, height: 24))
            field.font = .systemFont(ofSize: 11)
            field.placeholderString = L.typeAnswer
            field.target = self
            field.action = #selector(inputSubmitted) // Enter envia
            container.addSubview(field)
            inputField = field

            let send = FirstClickButton(
                title: L.send, target: self, action: #selector(inputSubmitted))
            send.bezelStyle = .rounded
            send.controlSize = .small
            send.font = .systemFont(ofSize: 11)
            send.frame = NSRect(x: w - 12 - 80, y: 10, width: 80, height: 24)
            container.addSubview(send)

            let terminal = FirstClickButton(
                title: L.answerInTerminal, target: self,
                action: #selector(terminalButtonClicked(_:)))
            terminal.bezelStyle = .inline
            terminal.controlSize = .small
            terminal.font = .systemFont(ofSize: 10)
            terminal.frame = NSRect(x: 12, y: 12, width: w - 24 - 88, height: 20)
            container.addSubview(terminal)
        } else if let optionLabels = ask.options {
            // opções empilhadas; tag = índice da opção
            for (i, label) in optionLabels.enumerated() {
                let button = FirstClickButton(
                    title: label, target: self, action: #selector(optionButtonClicked(_:)))
                button.tag = i
                button.bezelStyle = .rounded
                button.controlSize = .small
                button.font = .systemFont(ofSize: 11)
                button.frame = NSRect(
                    x: 12, y: 36 + CGFloat(optionLabels.count - 1 - i) * 30,
                    width: w - 24, height: 24)
                container.addSubview(button)
            }
            let terminal = FirstClickButton(
                title: L.answerInTerminal, target: self,
                action: #selector(terminalButtonClicked(_:)))
            terminal.bezelStyle = .inline
            terminal.controlSize = .small
            terminal.font = .systemFont(ofSize: 10)
            terminal.frame = NSRect(x: 12, y: 8, width: w - 24, height: 20)
            container.addSubview(terminal)
        } else {
            let labels = [L.allow, L.deny, L.terminal]
            let buttonWidth = (w - 24 - 16) / 3
            for (i, label) in labels.enumerated() {
                let button = FirstClickButton(
                    title: label, target: self, action: #selector(permissionButtonClicked(_:)))
                button.tag = i
                button.bezelStyle = .rounded
                button.controlSize = .small
                button.font = .systemFont(ofSize: 11)
                button.frame = NSRect(
                    x: 12 + CGFloat(i) * (buttonWidth + 8), y: 10,
                    width: buttonWidth, height: 24)
                container.addSubview(button)
            }
        }

        bubble.contentView = container
        if isInput {
            bubble.makeKeyAndOrderFront(nil)
            bubble.makeFirstResponder(inputField)
        } else {
            bubble.orderFrontRegardless()
        }
        bubbleWindow = bubble
    }

    // atalhos com o balão focado (clicado): 1..4 escolhem, Esc = terminal
    func handleBubbleKey(_ event: NSEvent) -> Bool {
        guard let current = currentAsk else { return false }
        if event.keyCode == 53 { // Esc
            focusClaudeApp()
            answerCurrentAsk("ask")
            return true
        }
        guard current.payload.input != true, let chars = event.characters,
              let digit = Int(chars), digit >= 1
        else { return false }
        if let options = current.payload.options {
            guard digit <= options.count else { return false }
            answerCurrentAsk("opt:\(digit - 1)")
        } else {
            guard digit <= 3 else { return false }
            if digit == 3 { focusClaudeApp() }
            answerCurrentAsk(["allow", "deny", "ask"][digit - 1])
        }
        return true
    }

    @objc func permissionButtonClicked(_ sender: NSButton) {
        let answer = ["allow", "deny", "ask"][sender.tag]
        if answer == "ask" { focusClaudeApp() }
        answerCurrentAsk(answer)
    }

    @objc func optionButtonClicked(_ sender: NSButton) {
        answerCurrentAsk("opt:\(sender.tag)")
    }

    @objc func inputSubmitted() {
        let text = (inputField?.stringValue ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        answerCurrentAsk("txt:" + text)
    }

    @objc func terminalButtonClicked(_ sender: NSButton) {
        focusClaudeApp()
        answerCurrentAsk("ask")
    }

    // ------------------------------------------------------------------
    // Renderização: atualiza janela flutuante e ícone da barra juntos
    // ------------------------------------------------------------------

    private func applyState(_ newState: PetState) {
        state = newState
        frameIndex = 0
        quirk = []
        quirkIndex = 0
        animTimer?.invalidate()
        animTimer = Timer.scheduledTimer(withTimeInterval: newState.interval, repeats: true) {
            [weak self] _ in
            guard let self else { return }
            if !self.quirk.isEmpty {
                self.quirkIndex += 1
                if self.quirkIndex >= self.quirk.count {
                    self.quirk = []
                    self.quirkIndex = 0
                    self.frameIndex = 0
                }
            } else {
                self.frameIndex = (self.frameIndex + 1) % self.state.frames.count
            }
            self.render()
        }
        render()
    }

    private func render() {
        var grid = quirk.isEmpty
            ? state.frames[frameIndex]
            : quirk[min(quirkIndex, quirk.count - 1)]
        // olhos seguem o mouse (menos no laptop, onde ele está concentrado)
        var lookingLeft = false
        if state != .working {
            lookingLeft = NSEvent.mouseLocation.x < window.frame.midX
            grid = eyesLooking(left: lookingLeft, grid)
        }
        let level = stats.level.number
        grid = overlaySweat(overlayBadges(overlayAccessory(grid, level: level)))
        petView.grid = grid
        petView.needsDisplay = true
        // quadros de mania não entram no cache (são transitórios e variados)
        let key = quirk.isEmpty
            ? "\(state.rawValue)-\(frameIndex)-\(min(workingCount, 4))-\(isSweating ? 1 : 0)-\(lookingLeft ? 1 : 0)-\(level)"
            : nil
        statusItem.button?.image = barImage(for: grid, key: key)
    }

    private func barImage(for grid: [String], key: String?) -> NSImage {
        if let key, let cached = barImageCache[key] { return cached }
        let size = NSSize(
            width: CGFloat(gridCols) * barPixelSize,
            height: CGFloat(gridRows) * barPixelSize)
        let image = NSImage(size: size)
        image.lockFocus()
        drawGrid(grid, pixel: barPixelSize, height: size.height)
        image.unlockFocus()
        if let key { barImageCache[key] = image }
        return image
    }
}

final class PetView: NSView {
    var grid: [String] = []
    var onAcknowledge: (() -> Void)?
    var onMoved: (() -> Void)?

    private var initialMouse: NSPoint = .zero
    private var initialOrigin: NSPoint = .zero
    private var didDrag = false

    override func draw(_ dirtyRect: NSRect) {
        drawGrid(grid, pixel: pixelSize, height: bounds.height)
    }

    // Clique esquerdo: foca quem precisa e reconhece avisos.
    // Arrastar: move o Craby (posição fica salva). Clique direito: sai.
    // O arrasto é rastreado manualmente para nunca confundir clique com arrasto.
    override func mouseDown(with event: NSEvent) {
        initialMouse = NSEvent.mouseLocation
        initialOrigin = window?.frame.origin ?? .zero
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let win = window else { return }
        let loc = NSEvent.mouseLocation
        let dx = loc.x - initialMouse.x
        let dy = loc.y - initialMouse.y
        if !didDrag && abs(dx) < 3 && abs(dy) < 3 { return } // tolerância de clique
        didDrag = true
        win.setFrameOrigin(NSPoint(x: initialOrigin.x + dx, y: initialOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if didDrag {
            onMoved?()
        } else {
            onAcknowledge?()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        NSApp.terminate(nil)
    }
}
