import AppKit
import ApplicationServices
import Network

// ---------------------------------------------------------------------------
// Grade
// ---------------------------------------------------------------------------

let gridCols = 14
let gridRows = 14 // 4 de efeitos + 10 de caranguejo
let pixelSize: CGFloat = 5
let barPixelSize: CGFloat = 1.3 // pixel do ícone da menu bar (~18pt no total)
let bubbleWidth: CGFloat = 280
let bubbleHeight: CGFloat = 104

// ---------------------------------------------------------------------------
// Pixel art: cada string é uma linha, cada caractere um pixel.
// R corpo, D sombra, W branco do olho, B pupila, Y amarelo (efeitos), . transparente
// Cada quadro = 4 linhas de "efeitos" (área acima da cabeça) + 10 linhas de caranguejo.
// ---------------------------------------------------------------------------

let emptyFx = [
    "..............",
    "..............",
    "..............",
    "..............",
]

let exclaimFx = [
    "......YY......",
    "......YY......",
    "..............",
    "......YY......",
]

let sparkleFx1 = [
    "..Y.......Y...",
    "..............",
    "......Y.......",
    "..............",
]

let sparkleFx2 = [
    "..............",
    "....Y....Y....",
    "..............",
    ".Y..........Y.",
]

let clawsUp = [
    ".RR........RR.",
    ".RR........RR.",
    "..R........R..",
    "..RRRRRRRRRR..",
    ".RRWBRRRRWBRR.",
    ".RRRRRRRRRRRR.",
    ".RDRRRRRRRRDR.",
    "..RRRRRRRRRR..",
    ".R.R..RR..R.R.",
    "R..R..RR..R..R",
]

let clawsDown = [
    "..............",
    "RRR........RRR",
    ".R..........R.",
    "..RRRRRRRRRR..",
    ".RRWBRRRRWBRR.",
    ".RRRRRRRRRRRR.",
    ".RDRRRRRRRRDR.",
    "..RRRRRRRRRR..",
    "R..R..RR..R..R",
    ".R.R..RR..R.R.",
]

let leftUpRightDown = [
    ".RR...........",
    ".RR........RRR",
    "..R........R..",
    "..RRRRRRRRRR..",
    ".RRWBRRRRWBRR.",
    ".RRRRRRRRRRRR.",
    ".RDRRRRRRRRDR.",
    "..RRRRRRRRRR..",
    ".R.R..RR..R.R.",
    "R..R..RR..R..R",
]

let rightUpLeftDown = [
    "...........RR.",
    "RRR........RR.",
    ".R.........R..",
    "..RRRRRRRRRR..",
    ".RRWBRRRRWBRR.",
    ".RRRRRRRRRRRR.",
    ".RDRRRRRRRRDR.",
    "..RRRRRRRRRR..",
    "R..R..RR..R..R",
    ".R.R..RR..R.R.",
]

// trabalhando: debruçado no laptop, garras alternando no teclado, teclas voando
// (grade completa de 14 linhas — não usa o prefixo de efeitos)
let laptopLeft = [
    "..............",
    "...Y..........",
    "..............",
    "..RRRRRRRRRR..",
    ".RRWBRRRRWBRR.",
    ".RRRRRRRRRRRR.",
    ".RDRRRRRRRRDR.",
    "..RRRRRRRRRR..",
    "...........RR.",
    ".RR........RR.",
    "..GGGGGGGGGG..",
    "..GLLLLLLLLG..",
    "..GGGGGGGGGG..",
    "..............",
]

let laptopRight = [
    "..............",
    "..........Y...",
    "..............",
    "..RRRRRRRRRR..",
    ".RRWBRRRRWBRR.",
    ".RRRRRRRRRRRR.",
    ".RDRRRRRRRRDR.",
    "..RRRRRRRRRR..",
    ".RR...........",
    ".RR........RR.",
    "..GGGGGGGGGG..",
    "..GLLLLLLLLG..",
    "..GGGGGGGGGG..",
    "..............",
]

// olhos fechados (piscada): troca branco+pupila por pálpebras escuras
func blinking(_ crab: [String]) -> [String] {
    crab.map { $0.replacingOccurrences(of: "WB", with: "DD") }
}

// pulo: desloca o caranguejo uma linha pra cima dentro da grade
func jumping(_ fx: [String], _ crab: [String]) -> [String] {
    Array(fx.dropLast()) + crab + [String(repeating: ".", count: gridCols)]
}

let palette: [Character: NSColor] = [
    "R": NSColor(red: 0.91, green: 0.35, blue: 0.24, alpha: 1.0),
    "D": NSColor(red: 0.72, green: 0.22, blue: 0.14, alpha: 1.0),
    "W": .white,
    "B": .black,
    "Y": NSColor(red: 1.0, green: 0.82, blue: 0.15, alpha: 1.0),
    "G": NSColor(red: 0.35, green: 0.39, blue: 0.45, alpha: 1.0),
    "L": NSColor(red: 0.60, green: 0.65, blue: 0.71, alpha: 1.0),
]

// ---------------------------------------------------------------------------
// Estados
// ---------------------------------------------------------------------------

enum PetState: String {
    case idle, working, done, attention

    var frames: [[String]] {
        switch self {
        case .idle:
            // tamborila devagar e pisca de vez em quando
            return [
                emptyFx + clawsUp,
                emptyFx + clawsDown,
                emptyFx + clawsUp,
                emptyFx + blinking(clawsDown),
            ]
        case .working:
            return [laptopLeft, laptopRight]
        case .done:
            // comemora pulando entre as faíscas
            return [sparkleFx1 + clawsUp, jumping(sparkleFx2, clawsUp)]
        case .attention:
            // acena alternando as garras com o "!" piscando
            return [
                exclaimFx + clawsUp,
                emptyFx + rightUpLeftDown,
                exclaimFx + clawsUp,
                emptyFx + leftUpRightDown,
            ]
        }
    }

    var interval: TimeInterval {
        switch self {
        case .idle: return 0.8
        case .working: return 0.2
        case .done: return 0.4
        case .attention: return 0.35
        }
    }

    // prioridade de exibição quando há várias sessões
    var priority: Int {
        switch self {
        case .attention: return 3
        case .working: return 2
        case .done: return 1
        case .idle: return 0
        }
    }

    var labelPt: String {
        switch self {
        case .idle: return "ocioso"
        case .working: return "trabalhando"
        case .done: return "terminou"
        case .attention: return "precisa de você"
        }
    }
}

func drawGrid(_ grid: [String], pixel: CGFloat, height: CGFloat) {
    for (row, line) in grid.enumerated() {
        for (col, ch) in line.enumerated() {
            guard let color = palette[ch] else { continue }
            color.setFill()
            NSRect(
                x: CGFloat(col) * pixel,
                // linhas do desenho são de cima pra baixo; o sistema desenha de baixo pra cima
                y: height - CGFloat(row + 1) * pixel,
                width: pixel,
                height: pixel
            ).fill()
        }
    }
}

// ---------------------------------------------------------------------------
// Servidor de controle
//   GET  /idle|working|done|attention[?session=id&project=nome]
//   GET  /quit
//   GET  /answer/<allow|deny|ask|opt:N|txt:...>   -> responde o pedido pendente
//   POST /ask {title, detail, urgent, options?, input?}
//        segura a conexão (long-poll) até a escolha do usuário
// ---------------------------------------------------------------------------

struct AskPayload: Codable {
    let title: String
    let detail: String
    let urgent: Bool
    // modo pergunta: rótulos das opções; modo texto: input=true;
    // nenhum dos dois = modo permissão (Permitir/Negar/Terminal)
    let options: [String]?
    let input: Bool?
}

struct HTTPRequest {
    let method: String
    let path: String
    let query: [String: String]
    let body: Data
}

final class ControlServer {
    let listener: NWListener
    let onCommand: (String, [String: String]) -> Void // (comando, query)
    let onAsk: (AskPayload, NWConnection) -> Void

    init(port: UInt16,
         onCommand: @escaping (String, [String: String]) -> Void,
         onAsk: @escaping (AskPayload, NWConnection) -> Void) throws {
        self.onCommand = onCommand
        self.onAsk = onAsk
        listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        listener.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .main)
            self?.receiveRequest(conn, buffer: Data())
        }
        listener.start(queue: .main)
    }

    private func receiveRequest(_ conn: NWConnection, buffer: Data) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 16384) {
            [weak self] data, _, isComplete, error in
            guard let self else { conn.cancel(); return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let request = Self.parse(buffer) {
                self.route(request, conn: conn)
            } else if !isComplete && error == nil {
                self.receiveRequest(conn, buffer: buffer) // corpo ainda não chegou inteiro
            } else {
                conn.cancel()
            }
        }
    }

    private func route(_ request: HTTPRequest, conn: NWConnection) {
        if request.method == "POST" && request.path == "/ask" {
            if let payload = try? JSONDecoder().decode(AskPayload.self, from: request.body) {
                onAsk(payload, conn) // conexão fica aberta; respond() é chamado depois
            } else {
                Self.respond(conn, body: "ask")
            }
            return
        }
        let command = request.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        onCommand(command.removingPercentEncoding ?? command, request.query)
        Self.respond(conn, body: "ok")
    }

    static func respond(_ conn: NWConnection, body: String) {
        let data = body.data(using: .utf8)!
        let response = "HTTP/1.1 200 OK\r\nContent-Length: \(data.count)\r\nConnection: close\r\n\r\n"
        conn.send(content: response.data(using: .utf8)! + data,
                  completion: .contentProcessed { _ in conn.cancel() })
    }

    static func parse(_ buffer: Data) -> HTTPRequest? {
        guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)),
              let head = String(data: buffer[buffer.startIndex..<headerEnd.lowerBound],
                                encoding: .utf8)
        else { return nil }
        let lines = head.components(separatedBy: "\r\n")
        let parts = lines[0].split(separator: " ")
        guard parts.count >= 2 else { return nil }
        var contentLength = 0
        for line in lines.dropFirst() {
            let kv = line.split(separator: ":", maxSplits: 1)
            if kv.count == 2, kv[0].lowercased() == "content-length" {
                contentLength = Int(kv[1].trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }
        let bodyAvailable = buffer.distance(from: headerEnd.upperBound, to: buffer.endIndex)
        guard bodyAvailable >= contentLength else { return nil }
        let body = buffer.subdata(
            in: headerEnd.upperBound..<buffer.index(headerEnd.upperBound, offsetBy: contentLength))

        // separa caminho e query string (valores com percent-encoding)
        let rawPath = String(parts[1])
        let pathParts = rawPath.split(separator: "?", maxSplits: 1)
        var query: [String: String] = [:]
        if pathParts.count == 2 {
            for pair in pathParts[1].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    let value = String(kv[1])
                    query[String(kv[0])] = value.removingPercentEncoding ?? value
                }
            }
        }
        return HTTPRequest(
            method: String(parts[0]),
            path: String(pathParts[0]),
            query: query,
            body: body)
    }
}

// ---------------------------------------------------------------------------
// Painel/botão que aceitam interação sem ativar o app
// ---------------------------------------------------------------------------

final class BubblePanel: NSPanel {
    override var canBecomeKey: Bool { true }
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
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var petView: PetView!
    var statusItem: NSStatusItem!
    var toggleMenuItem: NSMenuItem!
    var soundMenuItem: NSMenuItem!
    var server: ControlServer?

    var state: PetState = .idle
    var frameIndex = 0
    var animTimer: Timer?
    var maintenanceTimer: Timer?
    var barImageCache: [String: NSImage] = [:]
    var floatingVisible = true

    // estado por sessão do Claude Code (multi-sessão)
    var sessions: [String: SessionInfo] = [:]

    // fila de pedidos de permissão/pergunta
    var askQueue: [(payload: AskPayload, conn: NWConnection)] = []
    var currentAsk: (payload: AskPayload, conn: NWConnection)?
    var bubbleWindow: NSWindow?
    var inputField: NSTextField?
    var askTimeout: DispatchWorkItem?

    var soundsEnabled: Bool {
        UserDefaults.standard.object(forKey: "soundsEnabled") as? Bool ?? true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let width = CGFloat(gridCols) * pixelSize
        let height = CGFloat(gridRows) * pixelSize

        window = NSWindow(
            contentRect: frameForTopRight(width: width, height: height),
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

        petView = PetView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        petView.onAcknowledge = { [weak self] in self?.petClicked() }
        window.contentView = petView
        window.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.window.setFrame(
                self.frameForTopRight(width: width, height: height), display: true)
        }

        setupStatusItem()
        applyState(.idle)

        // reavalia sessões periodicamente (comemoração expira, sessões mortas somem)
        maintenanceTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) {
            [weak self] _ in self?.recomputeDisplayed()
        }

        do {
            server = try ControlServer(
                port: 4923,
                onCommand: { [weak self] command, query in
                    guard let self else { return }
                    if command == "quit" { NSApp.terminate(nil); return }
                    if command.hasPrefix("answer/") {
                        self.answerCurrentAsk(String(command.dropFirst("answer/".count)))
                        return
                    }
                    if let newState = PetState(rawValue: command) {
                        self.sessionEvent(
                            newState,
                            session: query["session"] ?? "default",
                            project: query["project"])
                    }
                },
                onAsk: { [weak self] payload, conn in
                    guard let self else { return }
                    self.askQueue.append((payload, conn))
                    if self.currentAsk == nil { self.showNextAsk() }
                }
            )
        } catch {
            NSLog("claude-pet: falha ao abrir porta 4923: \(error)")
        }
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let menu = NSMenu()
        toggleMenuItem = NSMenuItem(
            title: "Recolher para a barra",
            action: #selector(toggleFloating), keyEquivalent: "")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)
        soundMenuItem = NSMenuItem(
            title: "Sons", action: #selector(toggleSounds), keyEquivalent: "")
        soundMenuItem.target = self
        soundMenuItem.state = soundsEnabled ? .on : .off
        menu.addItem(soundMenuItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(
            title: "Sair", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    @objc func toggleFloating() {
        floatingVisible.toggle()
        if floatingVisible {
            window.orderFrontRegardless()
        } else {
            window.orderOut(nil)
        }
        toggleMenuItem.title = floatingVisible ? "Recolher para a barra" : "Mostrar flutuante"
    }

    @objc func toggleSounds() {
        UserDefaults.standard.set(!soundsEnabled, forKey: "soundsEnabled")
        soundMenuItem.state = soundsEnabled ? .on : .off
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
    // Multi-sessão: cada sessão tem um estado; o pet exibe o de maior prioridade
    // ------------------------------------------------------------------

    func sessionEvent(_ newState: PetState, session: String, project: String? = nil) {
        let existing = sessions[session]
        sessions[session] = SessionInfo(
            state: newState, at: Date(), project: project ?? existing?.project)
        recomputeDisplayed()
    }

    // clique no pet: se alguém precisa de você, foca a janela daquela sessão;
    // senão, só reconhece os avisos
    func petClicked() {
        if let needy = sessions.values.first(where: { $0.state == .attention }) {
            focusSession(project: needy.project)
        }
        for key in sessions.keys {
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
        let displayed = sessions.values.map(\.state).max(by: { $0.priority < $1.priority })
            ?? .idle
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
            petView.toolTip = "Claude Pet — tudo calmo"
        } else {
            petView.toolTip = active.values
                .map { "\($0.project ?? "sessão"): \($0.state.labelPt)" }
                .sorted()
                .joined(separator: "\n")
        }
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
        sessionEvent(.attention, session: "ask")
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
        ControlServer.respond(current.conn, body: answer)
        bubbleWindow?.orderOut(nil)
        bubbleWindow = nil
        inputField = nil
        currentAsk = nil
        sessionEvent(.working, session: "ask")
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
        let screen = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        // abaixo do pet, centralizado com ele (sem sair da tela)
        var x = petFrame.midX - w / 2
        x = max(screen.minX + 8, min(x, screen.maxX - w - 8))
        let y = petFrame.minY - h - 8

        let bubble = BubblePanel(
            contentRect: NSRect(x: x, y: y, width: w, height: h),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        bubble.isOpaque = false
        bubble.backgroundColor = .clear
        bubble.hasShadow = true
        bubble.level = .floating
        bubble.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let container = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 0.97).cgColor
        container.layer?.cornerRadius = 10
        container.layer?.borderWidth = 2
        container.layer?.borderColor =
            (ask.urgent ? NSColor.systemRed : NSColor.systemYellow).cgColor

        let title = NSTextField(labelWithString: ask.title)
        title.font = .boldSystemFont(ofSize: 11)
        title.textColor = .white
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
            field.placeholderString = "Digite sua resposta…"
            field.target = self
            field.action = #selector(inputSubmitted) // Enter envia
            container.addSubview(field)
            inputField = field

            let send = FirstClickButton(
                title: "Enviar", target: self, action: #selector(inputSubmitted))
            send.bezelStyle = .rounded
            send.controlSize = .small
            send.font = .systemFont(ofSize: 11)
            send.frame = NSRect(x: w - 12 - 80, y: 10, width: 80, height: 24)
            container.addSubview(send)

            let terminal = FirstClickButton(
                title: "Responder no terminal", target: self,
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
                title: "Responder no terminal", target: self,
                action: #selector(terminalButtonClicked(_:)))
            terminal.bezelStyle = .inline
            terminal.controlSize = .small
            terminal.font = .systemFont(ofSize: 10)
            terminal.frame = NSRect(x: 12, y: 8, width: w - 24, height: 20)
            container.addSubview(terminal)
        } else {
            let labels = ["Permitir", "Negar", "Terminal"]
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
        animTimer?.invalidate()
        animTimer = Timer.scheduledTimer(withTimeInterval: newState.interval, repeats: true) {
            [weak self] _ in
            guard let self else { return }
            self.frameIndex = (self.frameIndex + 1) % self.state.frames.count
            self.render()
        }
        render()
    }

    private func render() {
        let grid = overlayBadges(state.frames[frameIndex])
        petView.grid = grid
        petView.needsDisplay = true
        let key = "\(state.rawValue)-\(frameIndex)-\(min(workingCount, 4))"
        statusItem.button?.image = barImage(for: grid, key: key)
    }

    private func barImage(for grid: [String], key: String) -> NSImage {
        if let cached = barImageCache[key] { return cached }
        let size = NSSize(
            width: CGFloat(gridCols) * barPixelSize,
            height: CGFloat(gridRows) * barPixelSize)
        let image = NSImage(size: size)
        image.lockFocus()
        drawGrid(grid, pixel: barPixelSize, height: size.height)
        image.unlockFocus()
        barImageCache[key] = image
        return image
    }

    func frameForTopRight(width: CGFloat, height: CGFloat) -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let area = screen.visibleFrame // exclui a menu bar
        let margin: CGFloat = 12
        // afastado do canto: centralizado sobre a área onde o balão abre embaixo
        return NSRect(
            x: area.maxX - margin - bubbleWidth / 2 - width / 2,
            y: area.maxY - height - margin,
            width: width, height: height
        )
    }
}

final class PetView: NSView {
    var grid: [String] = []
    var onAcknowledge: (() -> Void)?

    override func draw(_ dirtyRect: NSRect) {
        drawGrid(grid, pixel: pixelSize, height: bounds.height)
    }

    // Clique esquerdo: foca quem precisa e reconhece avisos. Clique direito: sai.
    override func mouseDown(with event: NSEvent) {
        onAcknowledge?()
    }

    override func rightMouseDown(with event: NSEvent) {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // sem ícone no Dock, nunca rouba foco
let delegate = AppDelegate()
app.delegate = delegate
app.run()
