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
    var summary: String? // resuminho da última resposta (hook Stop)
    var source: String = "claude" // quem emite: claude, ci, docker, custom…
    var url: String? // alvo clicável (run do CI, PR…) — clique no pet abre
}

// vigília: coisas vivas (servidores, containers) que o Craby está de olho
struct WatchInfo {
    var label: String
    var source: String
    var url: String?
    var alive: Bool
    var at: Date
}

struct CrabyConfig: Codable {
    var ntfyTopic: String?
    var soundTheme: String? // classic | soft | retro
    var soundPack: [String: String]? // override por evento (ver Sounds.swift)
    var hideOnScreenShare: Bool? // padrão: true
    // ordem de preferência das fontes na cena de vigília: a PRIMEIRA fonte
    // ativa desta lista veste o Craby sozinha (props nunca se misturam)
    var sourcePriority: [String]? // padrão: ["ci", "docker"]
}

// filhote = um subagente em execução (hooks SubagentStart/SubagentStop)
enum BabyPhase {
    case hatching, alive, elderly, poof
}

struct Baby {
    var phase: BabyPhase = .hatching
    var tick = 0 // ticks (0,4s) na fase atual
    var failed = false
    let session: String
    let born = Date()
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

    // estado por sessão (multi-sessão, multi-fonte)
    var sessions: [String: SessionInfo] = [:]
    // itens sob vigília (POST /watch)
    var watches: [String: WatchInfo] = [:]
    // legenda persistente enquanto algo pede atenção
    var captionWindow: NSWindow?
    var captionIndex = 0

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
    let appVersion = "1.6.0"

    // uso do plano Claude (janelas 5h/semana); vazio = sem token/indisponível
    var planWindows: [PlanWindow] = []
    var planTimer: Timer?
    let planClient = PlanUsageClient()
    let addonManager = AddonManager()

    // ninhada de subagentes
    var babies: [Baby] = []
    var babyTimer: Timer?

    // frases do Craby (toasts), preferências e modo apresentação
    var toastWindow: NSWindow?
    var toastDismiss: DispatchWorkItem?
    var prefsWindow: NSWindow?
    var hiddenForSharing = false

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

        // janela inclui a faixa da ninhada abaixo do Craby
        let width = petWindowWidth
        let height = petWindowHeight

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
        addonManager.scan()
        applyState(.idle)

        // reavalia sessões periodicamente (comemoração expira, sessões mortas somem)
        // e dá chance das manias do ócio acontecerem
        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) {
            [weak self] _ in
            self?.recomputeDisplayed()
            self?.maybeQuirk()
            self?.updatePresentationMode()
        }

        do {
            server = try ControlServer(
                port: 4923,
                authToken: authToken,
                onCommand: { [weak self] command, query in
                    guard let self else { return nil }
                    if command == "quit" { NSApp.terminate(nil); return nil }
                    if command == "status" { return self.statusJSON() }
                    // GET / — playground pra testar o protocolo no navegador
                    if command.isEmpty || command == "playground" {
                        return playgroundHTML
                    }
                    // dados p/ o construtor de addons do playground
                    if command == "scenes" { return scenesJSON() }
                    if command == "subagent-start" {
                        self.babyBorn(session: query["session"] ?? "default")
                        return nil
                    }
                    if command == "subagent-stop" {
                        self.babyStopped(
                            session: query["session"] ?? "default",
                            failed: query["failed"] == "1")
                        return nil
                    }
                    if command.hasPrefix("answer/") {
                        self.answerCurrentAsk(String(command.dropFirst("answer/".count)))
                        return nil
                    }
                    if command == "celebrate" {
                        self.celebrate(query["text"])
                        return nil
                    }
                    // evento estruturado (qualquer cérebro): /event?source=ci&
                    //   session=id&state=working|done|attention|idle&project=&detail=&url=
                    if command == "event" {
                        guard let state = PetState(rawValue: query["state"] ?? "")
                        else { return "bad state" }
                        let source = query["source"] ?? "custom"
                        let session = query["session"] ?? "default"
                        self.sessionEvent(
                            state,
                            session: source == "claude" ? session : "\(source):\(session)",
                            project: query["project"],
                            summary: query["detail"],
                            source: source,
                            url: query["url"])
                        return nil
                    }
                    // vigília: /watch?id=x&label=&source=&url=&status=alive|dead|gone
                    if command == "watch" {
                        guard let id = query["id"], !id.isEmpty else { return "bad id" }
                        self.watchEvent(
                            id: id,
                            label: query["label"] ?? id,
                            source: query["source"] ?? "custom",
                            url: query["url"],
                            status: query["status"] ?? "alive")
                        return nil
                    }
                    if let newState = PetState(rawValue: command) {
                        self.sessionEvent(
                            newState,
                            session: query["session"] ?? "default",
                            project: query["project"],
                            summary: query["summary"])
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

        babyTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) {
            [weak self] _ in self?.babyTick()
        }

        // uso do plano: 1ª consulta 10s após abrir, depois a cada 5min
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            self?.refreshPlan()
        }
        planTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) {
            [weak self] _ in self?.refreshPlan()
        }
    }

    // ------------------------------------------------------------------
    // Uso do plano: janela de 5h e semana, direto da conta Claude
    // ------------------------------------------------------------------

    func refreshPlan() {
        planClient.fetch { [weak self] windows in
            DispatchQueue.main.async {
                guard let self else { return }
                self.planWindows = windows ?? []
                self.updateTooltip()
                self.render() // o suor de "plano quase cheio" pode mudar
            }
        }
    }

    var planFiveHour: PlanWindow? {
        planWindows.first { $0.key == "five_hour" }
    }

    // plano apertado: 80%+ da janela de 5h consumida -> Craby fica ofegante
    var planStrained: Bool {
        (planFiveHour?.utilization ?? 0) >= 80
    }

    func planLines() -> [String] {
        planWindows.compactMap { w in
            let pct = Int(w.utilization)
            var reset = ""
            if let at = w.resetsAt {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                reset = formatter.string(from: at)
            }
            switch w.key {
            case "five_hour": return L.plan5h(pct, reset: reset)
            case "seven_day": return L.planWeek(pct)
            case "seven_day_opus": return nil // só interessa a quem usa; some
            default: return "\(w.key): \(pct)%"
            }
        }
    }

    // ------------------------------------------------------------------
    // Ninhada: ovo racha -> filhote tamborila -> bengala -> puf
    // ------------------------------------------------------------------

    func babyBorn(session: String) {
        lastEventAt = Date() // ninhada nova também acorda o Craby
        babies.append(Baby(session: session))
        if stats.recordBrood(count: liveBabyCount()) {
            showToast(L.broodRecord(liveBabyCount()))
        }
        renderBabies()
    }

    func babyStopped(session: String, failed: Bool) {
        guard let i = babies.firstIndex(where: {
            $0.session == session && ($0.phase == .alive || $0.phase == .hatching)
        }) else { return }
        babies[i].phase = .elderly
        babies[i].tick = 0
        babies[i].failed = failed
        renderBabies()
    }

    func babyTick() {
        guard !babies.isEmpty else { return }
        for i in babies.indices {
            babies[i].tick += 1
            switch babies[i].phase {
            case .hatching:
                if babies[i].tick >= 4 {
                    babies[i].phase = .alive
                    babies[i].tick = 0
                    play(.hatch)
                }
            case .alive:
                // órfão (o stop nunca veio): aposenta como falha após 30min
                if Date().timeIntervalSince(babies[i].born) > 1800 {
                    babies[i].phase = .elderly
                    babies[i].tick = 0
                    babies[i].failed = true
                }
            case .elderly:
                if babies[i].tick >= 6 { // ~2,4s de bengala
                    babies[i].phase = .poof
                    babies[i].tick = 0
                    play(babies[i].failed ? .poofFail : .poofOk)
                }
            case .poof:
                break
            }
        }
        babies.removeAll { $0.phase == .poof && $0.tick >= 2 }
        renderBabies()
    }

    private func babyGrid(_ baby: Baby) -> [String] {
        switch baby.phase {
        case .hatching:
            return baby.tick < 2 ? babyEgg : babyEggCracking
        case .alive:
            return baby.tick % 2 == 0 ? babyAlive1 : babyAlive2
        case .elderly:
            return babyElderly
        case .poof:
            let grid = baby.tick < 1 ? babyPoof1 : babyPoof2
            return baby.failed ? failedRecolor(grid) : grid
        }
    }

    private func renderBabies() {
        petView.babyGrids = babies.map(babyGrid)
        petView.needsDisplay = true
    }

    func liveBabyCount(session: String? = nil) -> Int {
        babies.filter {
            ($0.phase == .alive || $0.phase == .hatching)
                && (session == nil || $0.session == session)
        }.count
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

    // ------------------------------------------------------------------
    // Auto-update: baixa o zip do release, troca o bundle e reinicia
    // ------------------------------------------------------------------

    @objc func updateNow() {
        guard let version = availableUpdate,
              let url = URL(string:
                "https://github.com/duperez/crab-companion/releases/download/v\(version)/Craby.app.zip")
        else { return }
        showToast(L.updating, seconds: 30)
        URLSession.shared.downloadTask(with: url) { [weak self] tmp, _, error in
            DispatchQueue.main.async { self?.installUpdate(from: tmp, error: error) }
        }.resume()
    }

    private func runTool(_ path: String, _ args: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch { return false }
    }

    private func installUpdate(from tmp: URL?, error: Error?) {
        guard let tmp, error == nil else {
            showToast(L.updateFailed)
            openReleases()
            return
        }
        let bundleURL = Bundle.main.bundleURL // .../Craby.app
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("craby-update-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(
                at: staging, withIntermediateDirectories: true)
            guard runTool("/usr/bin/ditto", ["-x", "-k", tmp.path, staging.path]) else {
                throw CocoaError(.fileReadUnknown)
            }
            let newApp = staging.appendingPathComponent("Craby.app")
            let newBinary = newApp.appendingPathComponent("Contents/MacOS/pet")
            guard FileManager.default.isExecutableFile(atPath: newBinary.path) else {
                throw CocoaError(.fileNoSuchFile)
            }
            _ = runTool("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])
            try? FileManager.default.removeItem(at: bundleURL)
            try FileManager.default.moveItem(at: newApp, to: bundleURL)
            // o LaunchAgent nos derruba e sobe a versão nova
            _ = runTool("/bin/launchctl",
                        ["kickstart", "-k", "gui/\(getuid())/com.crab-companion.pet"])
            // se não estivermos sob o launchd, encerra mesmo assim (usuário reabre)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { NSApp.terminate(nil) }
        } catch {
            showToast(L.updateFailed)
            openReleases()
        }
    }

    // ------------------------------------------------------------------
    // Modo apresentação: some quando a tela está sendo compartilhada
    // (melhor esforço — cobre compartilhamento de tela do sistema)
    // ------------------------------------------------------------------

    func isScreenShared() -> Bool {
        guard config.hideOnScreenShare ?? true else { return false }
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return false
        }
        return (dict["CGSSessionScreenIsShared"] as? Bool) ?? false
    }

    func updatePresentationMode() {
        let shared = isScreenShared()
        if shared && !hiddenForSharing {
            hiddenForSharing = true
            window.orderOut(nil)
            toastWindow?.orderOut(nil)
        } else if !shared && hiddenForSharing {
            hiddenForSharing = false
            if floatingVisible { window.orderFrontRegardless() }
        }
    }

    // ------------------------------------------------------------------
    // Preferências
    // ------------------------------------------------------------------

    var ntfyField: NSTextField?

    @objc func openPreferences() {
        if prefsWindow == nil { buildPreferencesWindow() }
        ntfyField?.stringValue = config.ntfyTopic ?? ""
        prefsWindow?.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func buildPreferencesWindow() {
        let w: CGFloat = 400
        let h: CGFloat = 240
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        win.title = L.prefsTitle
        win.isReleasedWhenClosed = false
        win.center()
        let content = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))

        let ntfyLabel = NSTextField(labelWithString: L.prefsNtfy)
        ntfyLabel.frame = NSRect(x: 20, y: h - 40, width: w - 40, height: 18)
        content.addSubview(ntfyLabel)

        let field = NSTextField(frame: NSRect(x: 20, y: h - 68, width: w - 40, height: 24))
        field.placeholderString = "meu-topico-secreto"
        field.target = self
        field.action = #selector(ntfyChanged(_:))
        content.addSubview(field)
        ntfyField = field

        let soundsCheck = NSButton(
            checkboxWithTitle: L.sounds, target: self, action: #selector(prefsSoundsToggled(_:)))
        soundsCheck.state = soundsEnabled ? .on : .off
        soundsCheck.frame = NSRect(x: 20, y: h - 100, width: 160, height: 20)
        content.addSubview(soundsCheck)

        let themeLabel = NSTextField(labelWithString: L.prefsSoundTheme)
        themeLabel.frame = NSRect(x: 200, y: h - 100, width: 100, height: 18)
        content.addSubview(themeLabel)

        let themePopup = NSPopUpButton(
            frame: NSRect(x: 295, y: h - 104, width: 90, height: 26))
        for key in soundThemeOrder { themePopup.addItem(withTitle: L.themeName(key)) }
        themePopup.selectItem(
            at: soundThemeOrder.firstIndex(of: config.soundTheme ?? "classic") ?? 0)
        themePopup.target = self
        themePopup.action = #selector(themeChanged(_:))
        content.addSubview(themePopup)

        let shareCheck = NSButton(
            checkboxWithTitle: L.prefsHideOnShare, target: self,
            action: #selector(hideOnShareToggled(_:)))
        shareCheck.state = (config.hideOnScreenShare ?? true) ? .on : .off
        shareCheck.frame = NSRect(x: 20, y: h - 132, width: w - 40, height: 20)
        content.addSubview(shareCheck)

        let openFolder = NSButton(
            title: L.prefsOpenFolder, target: self, action: #selector(openConfigFolder))
        openFolder.bezelStyle = .rounded
        openFolder.frame = NSRect(x: 20, y: 20, width: 200, height: 30)
        content.addSubview(openFolder)

        let reset = NSButton(
            title: L.resetPosition, target: self, action: #selector(resetPosition))
        reset.bezelStyle = .rounded
        reset.frame = NSRect(x: 230, y: 20, width: 150, height: 30)
        content.addSubview(reset)

        win.contentView = content
        prefsWindow = win
    }

    @objc func ntfyChanged(_ sender: NSTextField) {
        let value = sender.stringValue.trimmingCharacters(in: .whitespaces)
        config.ntfyTopic = value.isEmpty ? nil : value
        saveConfig()
    }

    @objc func prefsSoundsToggled(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: "soundsEnabled")
    }

    @objc func themeChanged(_ sender: NSPopUpButton) {
        let idx = sender.indexOfSelectedItem
        config.soundTheme = soundThemeOrder[min(max(idx, 0), soundThemeOrder.count - 1)]
        saveConfig()
        play(.done) // preview do tema
    }

    @objc func hideOnShareToggled(_ sender: NSButton) {
        config.hideOnScreenShare = sender.state == .on
        saveConfig()
    }

    @objc func openConfigFolder() {
        NSWorkspace.shared.open(appSupportDir)
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
                "source": info.source,
                "url": info.url ?? "",
            ]
        }
        let watchList = watches.map { id, info in
            [
                "id": id,
                "label": info.label,
                "source": info.source,
                "alive": info.alive ? "true" : "false",
                "url": info.url ?? "",
            ]
        }
        let payload: [String: Any] = [
            "version": appVersion,
            "displayed": state.rawValue,
            "totalTasks": stats.data.totalTasks,
            "subagents": liveBabyCount(),
            "sessions": sessionList,
            "watches": watchList,
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

    func saveConfig() {
        let url = appSupportDir.appendingPathComponent("config.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let raw = try? encoder.encode(config) {
            try? raw.write(to: url, options: .atomic)
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

        let header = NSMenuItem(
            title: L.totalLine(stats.data.totalTasks), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let day = stats.today
        let todayItem = NSMenuItem(
            title: L.todayLine(
                tasks: day.tasks, projects: day.projects.count, workSeconds: day.workSeconds),
            action: nil, keyEquivalent: "")
        todayItem.isEnabled = false
        menu.addItem(todayItem)

        if let maxBrood = day.maxBrood, maxBrood > 1 {
            let broodItem = NSMenuItem(
                title: L.broodLine(maxBrood), action: nil, keyEquivalent: "")
            broodItem.isEnabled = false
            menu.addItem(broodItem)
        }

        // addons: liga/desliga + pasta
        addonManager.scan()
        if !addonManager.addons.isEmpty {
            let header = NSMenuItem(title: "🧩 Addons:", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for (i, addon) in addonManager.addons.enumerated() {
                let item = NSMenuItem(
                    title: "   \(addon.manifest.name)"
                        + (addon.manifest.description.map { " — \($0)" } ?? ""),
                    action: #selector(toggleAddon(_:)), keyEquivalent: "")
                item.target = self
                item.tag = i
                item.state = addonManager.isEnabled(addon) ? .on : .off
                menu.addItem(item)
            }
        }
        let addonsFolder = NSMenuItem(
            title: L.openAddonsFolder, action: #selector(openAddonsFolder),
            keyEquivalent: "")
        addonsFolder.target = self
        menu.addItem(addonsFolder)
        menu.addItem(NSMenuItem.separator())

        // itens sob vigília: clicáveis quando têm URL
        if !watches.isEmpty {
            let watchHeader = NSMenuItem(
                title: "👁 \(L.watching):", action: nil, keyEquivalent: "")
            watchHeader.isEnabled = false
            menu.addItem(watchHeader)
            for (_, info) in watches.sorted(by: { $0.value.label < $1.value.label }) {
                let item = NSMenuItem(
                    title: "   \(info.alive ? "🟢" : "🔴") \(info.label) · \(info.source)",
                    action: info.url != nil ? #selector(watchItemClicked(_:)) : nil,
                    keyEquivalent: "")
                item.target = self
                item.representedObject = info.url
                menu.addItem(item)
            }
        }

        // janelas do plano Claude (só aparece se houver token disponível)
        for line in planLines() {
            let planItem = NSMenuItem(
                title: (planStrained ? "🥵 " : "🔋 ") + line,
                action: nil, keyEquivalent: "")
            planItem.isEnabled = false
            menu.addItem(planItem)
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
                case "level": kind = "🎉" // eventos antigos de nível (deprecado)
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
                title: "🆕 " + L.updateNow(update),
                action: #selector(updateNow), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }

        let prefs = NSMenuItem(
            title: L.preferences, action: #selector(openPreferences), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

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

    func play(_ event: SoundEvent) {
        guard soundsEnabled else { return }
        NSSound(named: soundName(
            event: event, theme: config.soundTheme, overrides: config.soundPack))?.play()
    }

    func playSound(for newState: PetState) {
        switch newState {
        case .done: play(.done)
        case .attention: play(.attention)
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

    func sessionEvent(
        _ newState: PetState, session: String, project: String? = nil,
        summary: String? = nil, source: String = "claude", url: String? = nil
    ) {
        let now = Date()
        maybeGreet() // primeiro evento do dia rende um "bom dia"
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
            stats.recordDone(project: proj ?? "?")
            if [5, 10, 20, 50].contains(stats.today.tasks) {
                showToast(L.tasksMilestone(stats.today.tasks))
            } else if let summary, !summary.isEmpty, session != "ask" {
                showToast("✅ \(proj ?? "?"): \(String(summary.prefix(80)))")
            }
        }
        if newState == .attention {
            stats.recordAttention(project: proj ?? "?")
            maybeNotifyPhone(project: proj)
        }

        sessions[session] = SessionInfo(
            state: newState, at: now, project: proj, workingSince: workingSince,
            summary: summary ?? existing?.summary,
            source: source, url: url ?? existing?.url)
        recomputeDisplayed()
    }

    // ------------------------------------------------------------------
    // Vigília: registrar/atualizar itens vivos; queda vira attention
    // ------------------------------------------------------------------

    func watchEvent(id: String, label: String, source: String, url: String?, status: String) {
        lastEventAt = Date()
        switch status {
        case "dead":
            let info = watches[id]
            watches[id] = WatchInfo(
                label: info?.label ?? label, source: info?.source ?? source,
                url: url ?? info?.url, alive: false, at: Date())
            // queda pede sua atenção pelas vias normais (legenda, clique, ntfy)
            sessionEvent(
                .attention, session: "watch:\(id)",
                project: info?.label ?? label,
                summary: L.watchDown(info?.label ?? label),
                source: info?.source ?? source, url: url ?? info?.url)
        case "gone":
            watches.removeValue(forKey: id)
            sessions.removeValue(forKey: "watch:\(id)")
            recomputeDisplayed()
        default: // "alive": registro ou batimento
            watches[id] = WatchInfo(
                label: label, source: source, url: url, alive: true, at: Date())
            sessions.removeValue(forKey: "watch:\(id)") // limpa alarme antigo
            recomputeDisplayed()
        }
    }

    // "bom dia" uma vez por dia, no primeiro sinal de vida
    private func maybeGreet() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        guard UserDefaults.standard.string(forKey: "lastGreetDay") != today else { return }
        UserDefaults.standard.set(today, forKey: "lastGreetDay")
        showToast(L.goodMorning)
    }

    // clique no pet: se alguém precisa de você, foca a janela daquela sessão;
    // e reconhece só os AVISOS (attention/done) — trabalho em andamento continua
    func petClicked() {
        if let needy = sessions.values.first(where: { $0.state == .attention }) {
            // alvo clicável (run do CI, PR…) vence; senão, foca a janela do projeto
            if let raw = needy.url, let url = URL(string: raw) {
                NSWorkspace.shared.open(url)
            } else {
                focusSession(project: needy.project)
            }
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
        updateCaption()
        if displayed != state {
            playSound(for: displayed)
            applyState(displayed)
        } else {
            render() // pontinhos de sessões podem ter mudado
        }
    }

    // legenda persistente: enquanto algo pede atenção, o Craby diz QUEM chama
    // (atribuição na chamada; na calmaria a legenda some)
    func updateCaption() {
        let needy = sessions
            .filter { $0.value.state == .attention }
            .sorted { $0.key < $1.key }
        guard !needy.isEmpty, floatingVisible, window.isVisible, !hiddenForSharing
        else {
            captionWindow?.orderOut(nil)
            captionWindow = nil
            return
        }
        if needy.count > 1 { captionIndex += 1 } // rotaciona a cada atualização
        let info = needy[captionIndex % needy.count].value
        var text = info.summary ?? info.project ?? L.sessionFallback
        if info.source != "claude", !(text.hasPrefix("[")) {
            text = "[\(info.source)] \(text)"
        }
        text = String(text.prefix(60))
        if needy.count > 1 { text += "  +\(needy.count - 1)" }

        // mesma legenda já na tela: só reposiciona (acompanha o pet)
        if let existing = captionWindow, existing.title == text {
            positionCaption(existing)
            return
        }
        captionWindow?.orderOut(nil)

        let font = NSFont.systemFont(ofSize: 11, weight: .medium)
        let size = (text as NSString).size(withAttributes: [.font: font])
        let w = min(size.width + 22, 280)
        let h: CGFloat = 22

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.title = text
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true // clique é no pet, não na legenda
        panel.hasShadow = true

        let box = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        box.wantsLayer = true
        box.layer?.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 0.95).cgColor
        box.layer?.cornerRadius = 6
        box.layer?.borderWidth = 1.5
        box.layer?.borderColor = NSColor.systemYellow.cgColor
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = .white
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: 10, y: 3, width: w - 20, height: 16)
        box.addSubview(label)
        panel.contentView = box

        positionCaption(panel)
        panel.orderFrontRegardless()
        captionWindow = panel
    }

    private func positionCaption(_ panel: NSWindow) {
        let pet = window.frame
        let area = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var x = pet.midX - panel.frame.width / 2
        x = max(area.minX + 4, min(x, area.maxX - panel.frame.width - 4))
        var y = pet.minY - panel.frame.height - 4
        if y < area.minY + 4 { y = pet.maxY + 4 }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // cenas + slots + paleta em JSON (construtor visual de addons)
    func scenesJSON() -> String {
        func hex(_ color: NSColor) -> String {
            let c = color.usingColorSpace(.deviceRGB) ?? color
            return String(
                format: "#%02x%02x%02x",
                Int(c.redComponent * 255), Int(c.greenComponent * 255),
                Int(c.blueComponent * 255))
        }
        var palette: [String: String] = [:]
        for (ch, color) in defaultPalette { palette[String(ch)] = hex(color) }
        for (ch, color) in customPalette { palette[String(ch)] = hex(color) }

        func sceneDict(_ scene: Scene) -> [String: Any] {
            var slots: [String: Any] = [:]
            for (name, slot) in scene.slots {
                slots[name] = [
                    "x": slot.pos[0].x, "y": slot.pos[0].y,
                    "w": slot.maxW, "h": slot.maxH,
                ]
            }
            return ["frame": scene.frames[0], "slots": slots]
        }
        let payload: [String: Any] = [
            "palette": palette,
            "scenes": [
                "idle": sceneDict(sceneIdle),
                "atento": sceneDict(sceneAtento),
                "debrucado": sceneDict(sceneDebrucado),
                "comemorando": sceneDict(sceneComemorando),
                "deitado": sceneDict(sceneDeitado),
            ],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }

    @objc func toggleAddon(_ sender: NSMenuItem) {
        guard sender.tag < addonManager.addons.count else { return }
        let addon = addonManager.addons[sender.tag]
        addonManager.setEnabled(addon, !addonManager.isEnabled(addon))
    }

    @objc func openAddonsFolder() {
        NSWorkspace.shared.open(addonManager.userAddonsDir)
    }

    @objc func watchItemClicked(_ sender: NSMenuItem) {
        if let raw = sender.representedObject as? String, let url = URL(string: raw) {
            NSWorkspace.shared.open(url)
        }
    }

    private func updateTooltip() {
        var planSuffix = planLines().isEmpty
            ? "" : "\n" + planLines().joined(separator: "\n")
        if !watches.isEmpty {
            let lines = watches.values
                .map { "👁 \($0.label): \($0.alive ? L.alive : L.down)" }
                .sorted()
            planSuffix = "\n" + lines.joined(separator: "\n") + planSuffix
        }
        let active = sessions.filter { $0.value.state != .idle }
        if active.isEmpty {
            petView.toolTip = L.allCalm + planSuffix
            return
        }
        let now = Date()
        petView.toolTip = active
            .map { key, info -> String in
                var name = info.project ?? L.sessionFallback
                if info.source != "claude" { name = "[\(info.source)] \(name)" }
                var line: String
                if info.state == .working, let since = info.workingSince {
                    let minutes = max(0, Int(now.timeIntervalSince(since) / 60))
                    line = "\(name): \(L.workingFor(minutes))"
                } else if info.state == .done, let summary = info.summary, !summary.isEmpty {
                    line = "\(name): ✅ \(String(summary.prefix(70)))"
                } else {
                    line = "\(name): \(L.stateLabel(info.state))"
                }
                let kids = liveBabyCount(session: key)
                if kids > 0 { line += " · \(kids) 🐣" }
                return line
            }
            .sorted()
            .joined(separator: "\n") + planSuffix
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
        // sua por esforço contínuo OU por plano quase esgotado (ofegante)
        guard isSweating || (planStrained && state != .sleeping) else { return grid }
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

    // festa avulsa (ex.: git push via hook pre-push) — confete + toast
    func celebrate(_ text: String?) {
        lastEventAt = Date() // acorda o Craby se estiver dormindo
        play(.levelUp)
        startQuirk(levelUpFrames + levelUpFrames)
        showToast(text?.isEmpty == false ? text! : L.pushParty)
    }

    // ------------------------------------------------------------------
    // Frases do Craby: mini-balão informativo que some sozinho
    // ------------------------------------------------------------------

    func showToast(_ text: String, seconds: Double = 5) {
        guard bubbleWindow == nil else { return } // balões de verdade têm prioridade
        toastDismiss?.cancel()
        toastWindow?.orderOut(nil)

        let width = min(300, max(120, CGFloat(text.count) * 6.5 + 28))
        let height: CGFloat = 30
        let petFrame = window.frame
        let screen = window.screen ?? NSScreen.main ?? NSScreen.screens[0]
        var x = petFrame.midX - width / 2
        x = max(screen.visibleFrame.minX + 8,
                min(x, screen.visibleFrame.maxX - width - 8))
        var y = petFrame.maxY + 6
        if y + height > screen.visibleFrame.maxY { y = petFrame.minY - height - 6 }

        let toast = BubblePanel(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        toast.isOpaque = false
        toast.backgroundColor = .clear
        toast.hasShadow = true
        toast.level = .floating
        toast.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        toast.ignoresMouseEvents = true

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 0.96).cgColor
        container.layer?.cornerRadius = 8
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor.systemYellow.withAlphaComponent(0.6).cgColor

        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: 10, y: 7, width: width - 20, height: 16)
        container.addSubview(label)

        toast.contentView = container
        toast.orderFrontRegardless()
        toastWindow = toast

        let dismiss = DispatchWorkItem { [weak self] in
            self?.toastWindow?.orderOut(nil)
            self?.toastWindow = nil
        }
        toastDismiss = dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: dismiss)
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
        if answer == "always", current.payload.rule != nil { valid = true }
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
            // +30 pra linha do "Sempre permitir" quando há regra sugerida
            h = bubbleHeight + (ask.rule != nil ? 30 : 0)
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
            // "Sempre permitir (regra)": grava na allowlist e permite
            if let rule = ask.rule {
                let always = FirstClickButton(
                    title: "\(L.alwaysAllow)  ·  \(rule)",
                    target: self, action: #selector(alwaysButtonClicked(_:)))
                always.bezelStyle = .rounded
                always.controlSize = .small
                always.font = .systemFont(ofSize: 11)
                always.lineBreakMode = .byTruncatingTail
                always.frame = NSRect(x: 12, y: 40, width: w - 24, height: 24)
                container.addSubview(always)
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
            // 4 = "Sempre permitir" (só quando há regra sugerida)
            if digit == 4, current.payload.rule != nil {
                answerCurrentAsk("always")
                return true
            }
            guard digit <= 3 else { return false }
            if digit == 3 { focusClaudeApp() }
            answerCurrentAsk(["allow", "deny", "ask"][digit - 1])
        }
        return true
    }

    @objc func alwaysButtonClicked(_ sender: NSButton) {
        answerCurrentAsk("always")
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

    // vigília ativa: o idle vira a cena "atento". Os props NUNCA se misturam:
    // a fonte ativa de maior prioridade veste o Craby sozinha (figurino do
    // addon vencedor); fontes sem prop próprio usam a lupa genérica.
    private var watchingFrames: [[String]] {
        let active = Set(watches.values.filter { $0.alive }.map(\.source))
        let order = config.sourcePriority ?? ["ci", "docker"]
        let winner = order.first(where: { active.contains($0) })
            ?? active.sorted().first
        // figurino declarado pelo addon vence; senão, defaults por fonte
        if let winner, let outfit = addonManager.outfit(for: winner) {
            return (0..<outfit.scene.frames.count).map {
                compose(scene: outfit.scene, props: outfit.props, frame: $0)
            }
        }
        let props: [Prop]
        switch winner {
        case "docker": props = [propCaixote]
        default: props = [propLupa] // ci e fontes sem figurino próprio
        }
        return (0..<sceneAtento.frames.count).map {
            compose(scene: sceneAtento, props: props, frame: $0)
        }
    }

    private func render() {
        var frames = quirk.isEmpty ? state.frames : []
        if quirk.isEmpty, state == .idle,
           watches.values.contains(where: { $0.alive }) {
            frames = watchingFrames
        }
        var grid = quirk.isEmpty
            ? frames[frameIndex % frames.count]
            : quirk[min(quirkIndex, quirk.count - 1)]
        // olhos seguem o mouse (menos no laptop, onde ele está concentrado)
        var lookingLeft = false
        if state != .working {
            lookingLeft = NSEvent.mouseLocation.x < window.frame.midX
            grid = eyesLooking(left: lookingLeft, grid)
        }
        grid = overlaySweat(overlayBadges(grid))
        petView.grid = grid
        petView.needsDisplay = true
        // quadros de mania não entram no cache (são transitórios e variados)
        let watching = quirk.isEmpty && state == .idle
            && watches.values.contains(where: { $0.alive })
        // o vencedor entra na chave do cache (figurinos diferentes por fonte)
        let watchTag = watching
            ? (watches.values.filter { $0.alive }.map(\.source).sorted().joined())
            : "n"
        let key = quirk.isEmpty
            ? "\(state.rawValue)-\(frameIndex)-\(min(workingCount, 4))-\(isSweating ? 1 : 0)-\(lookingLeft ? 1 : 0)-\(watchTag)"
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
    var babyGrids: [[String]] = []
    var onAcknowledge: (() -> Void)?
    var onMoved: (() -> Void)?

    private var initialMouse: NSPoint = .zero
    private var initialOrigin: NSPoint = .zero
    private var didDrag = false

    override func draw(_ dirtyRect: NSRect) {
        // Craby centralizado no alto; ninhada na faixa de baixo
        drawGridAt(grid, pixel: pixelSize, viewHeight: bounds.height,
                   originX: crabOffsetX, topY: 0)
        for (i, baby) in babyGrids.prefix(maxVisibleBabies).enumerated() {
            let x = 3 + CGFloat(i) * (CGFloat(babyCols) * babyPixel + 3)
            drawGridAt(baby, pixel: babyPixel, viewHeight: bounds.height,
                       originX: x, topY: petAreaHeight + 3)
        }
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
