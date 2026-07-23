import AppKit

// ---------------------------------------------------------------------------
// Grade
// ---------------------------------------------------------------------------

let gridCols = 14
let gridRows = 14 // 4 de efeitos + 10 de caranguejo
let pixelSize: CGFloat = 6
let barPixelSize: CGFloat = 1.3 // pixel do ícone da menu bar (~18pt no total)
let bubbleWidth: CGFloat = 280
let bubbleHeight: CGFloat = 104

// ninhada (subagentes): filhotes 7x6 numa faixa abaixo do Craby
let babyCols = 7
let babyRows = 6
let babyPixel: CGFloat = 3
let maxVisibleBabies = 5
let petAreaHeight: CGFloat = CGFloat(gridRows) * pixelSize // 70
let petWindowWidth: CGFloat = 124 // 5 filhotes de 21px + espaçamentos
let petWindowHeight: CGFloat = petAreaHeight + 24
let crabOffsetX: CGFloat = (petWindowWidth - CGFloat(gridCols) * pixelSize) / 2

// ---------------------------------------------------------------------------
// Pixel art: cada string é uma linha, cada caractere um pixel.
// R corpo, D sombra, W branco do olho, B pupila, Y amarelo (efeitos),
// G/L laptop, . transparente
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

// arte v2 (F2): talos, boquinha, garras-mão laterais, perninhas curtas
let idleV2a = [
    "..WB......WB..",
    "..WB......WB..",
    "..RRRRRRRRRR..",
    "RRRRRRRRRRRRRR",
    "R.RRRRrrRRRR.R",
    ".RrRRRRRRRRrR.",
    "..rRRRRRRRRr..",
    "..R..R..R..R..",
    "..r..r..r..r..",
    "..............",
]

// bob: talos abaixam e perninhas dão um passinho
let idleV2b = [
    "..............",
    "..WB......WB..",
    "..RRRRRRRRRR..",
    "RRRRRRRRRRRRRR",
    "R.RRRRrrRRRR.R",
    ".RrRRRRRRRRrR.",
    "..rRRRRRRRRr..",
    "...R..R..R..R.",
    "...r..r..r..r.",
    "..............",
]

// acenando/segurando: mão direita erguida ao lado do talo
let waveV2 = [
    "..WB......WB..",
    "..WB......WBR.",
    "..RRRRRRRRRRR.",
    "RRRRRRRRRRRRRR",
    "R.RRRRrrRRRRR.",
    ".RrRRRRRRRRrR.",
    "..rRRRRRRRRr..",
    "..R..R..R..R..",
    "..r..r..r..r..",
    "..............",
]

// comemorando: pinças abertas pro alto (o gesto reservado!)
let celebV2a = [
    "R..WB....WB..R",
    "RR.WB....WB.RR",
    ".R.RRRRRRRR.R.",
    "..RRRRRRRRRR..",
    ".RRRRRrrRRRRR.",
    "..rRRRRRRRRr..",
    "..R..R..R..R..",
    "..r..r..r..r..",
    "..............",
    "..............",
]

// pulinho: dedinhos fecham e perninhas recolhem
let celebV2b = [
    ".R.WB....WB.R.",
    "RR.WB....WB.RR",
    ".R.RRRRRRRR.R.",
    "..RRRRRRRRRR..",
    ".RRRRRrrRRRRR.",
    "..rRRRRRRRRr..",
    "...R..RR..R...",
    "..............",
    "..............",
    "..............",
]

// deitado dormindo: talos baixos, corpo largado no chão
let deitadoV2 = [
    "..............",
    "..............",
    "..............",
    "..............",
    "..............",
    "..WB......WB..",
    "..RRRRRRRRRR..",
    "RRRRRRRRRRRRRR",
    ".rRRRRrrRRRRr.",
    "..r..r..r..r..",
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

// dormindo: "Zzz" flutuando (dois quadros, o Z sobe)
let sleepFx1 = [
    "..........WWW.",
    "...........W..",
    "..........WWW.",
    "..............",
]

let sleepFx2 = [
    "......WWW.....",
    ".......W......",
    "......WWW.....",
    "..............",
]

// confete de level-up: pixels coloridos caindo
let confettiFx1 = [
    "Y..C....W..Y..",
    ".C....Y....C..",
    "..W..C...Y....",
    "..............",
]

let confettiFx2 = [
    ".C...Y...C..W.",
    "Y...W...Y.....",
    "...C...W...C..",
    "..............",
]

// olhos fechados (piscada): troca branco+pupila por pálpebras escuras
func blinking(_ crab: [String]) -> [String] {
    crab.map { $0.replacingOccurrences(of: "WB", with: "DD") }
}

// desloca a grade 1 pixel para o lado (passinho de caranguejo)
func shifted(_ grid: [String], dx: Int) -> [String] {
    grid.map { row in
        if dx > 0 { return "." + row.dropLast() }
        if dx < 0 { return row.dropFirst() + "." }
        return row
    }
}

// ---------------------------------------------------------------------------
// Filhotes (subagentes): nascem de um ovo, tamborilam enquanto o subagente
// roda, se aposentam de bengala e somem num puf de estrelinhas
// ---------------------------------------------------------------------------

let babyEgg = [
    "..WWW..",
    ".WWWWW.",
    ".WWWWW.",
    "..WWW..",
    ".......",
    ".......",
]

let babyEggCracking = [
    "..WWW..",
    ".WWBWW.",
    ".WBWWW.",
    "..WWW..",
    ".......",
    ".......",
]

let babyAlive1 = [
    "R.....R",
    ".RRRRR.",
    ".RBRBR.",
    ".RRRRR.",
    ".R.R.R.",
    ".......",
]

let babyAlive2 = [
    ".R...R.",
    ".RRRRR.",
    ".RBRBR.",
    ".RRRRR.",
    "R.R.R.R",
    ".......",
]

// aposentado: olhos cansados e bengala
let babyElderly = [
    "R....GG",
    ".RRRR.G",
    ".RDRDRG",
    ".RRRR.G",
    ".R.R.R.",
    ".......",
]

let babyPoof1 = [
    ".W...W.",
    "...Y...",
    ".W...W.",
    ".......",
    ".......",
    ".......",
]

let babyPoof2 = [
    "W..Y..W",
    ".......",
    "Y.....Y",
    "W..Y..W",
    ".......",
    ".......",
]

// puf de erro: cinza e vermelho em vez de estrelinhas douradas
func failedRecolor(_ grid: [String]) -> [String] {
    grid.map {
        $0.replacingOccurrences(of: "Y", with: "R")
            .replacingOccurrences(of: "W", with: "D")
    }
}

func isValidBabyFrame(_ frame: [String]) -> Bool {
    frame.count == babyRows && frame.allSatisfy { $0.count == babyCols }
}

// desenha uma grade com canto superior-esquerdo em (originX, topY),
// numa view de altura viewHeight
func drawGridAt(
    _ grid: [String], pixel: CGFloat, viewHeight: CGFloat,
    originX: CGFloat, topY: CGFloat
) {
    for (row, line) in grid.enumerated() {
        for (col, ch) in line.enumerated() {
            guard let color = paletteColor(ch) else { continue }
            color.setFill()
            NSRect(
                x: originX + CGFloat(col) * pixel,
                y: viewHeight - topY - CGFloat(row + 1) * pixel,
                width: pixel, height: pixel
            ).fill()
        }
    }
}

// olhos acompanham o mouse: pupila troca de lado quando ele está à esquerda
func eyesLooking(left: Bool, _ grid: [String]) -> [String] {
    guard left else { return grid }
    return grid.map { $0.replacingOccurrences(of: "WB", with: "BW") }
}

// pulo: desloca o caranguejo uma linha pra cima dentro da grade
func jumping(_ fx: [String], _ crab: [String]) -> [String] {
    Array(fx.dropLast()) + crab + [String(repeating: ".", count: gridCols)]
}

let defaultPalette: [Character: NSColor] = [
    "R": NSColor(red: 0.91, green: 0.35, blue: 0.24, alpha: 1.0),
    "D": NSColor(red: 0.72, green: 0.22, blue: 0.14, alpha: 1.0),
    "W": .white,
    "B": .black,
    "Y": NSColor(red: 1.0, green: 0.82, blue: 0.15, alpha: 1.0),
    "G": NSColor(red: 0.35, green: 0.39, blue: 0.45, alpha: 1.0),
    "L": NSColor(red: 0.60, green: 0.65, blue: 0.71, alpha: 1.0),
    "C": NSColor(red: 0.31, green: 0.76, blue: 0.97, alpha: 1.0),
    "r": NSColor(red: 0.68, green: 0.21, blue: 0.15, alpha: 1.0),  // sombra v2
]

// ---------------------------------------------------------------------------
// Sprites customizados (pacote da comunidade): ~/Library/Application Support/
// Craby/sprites.json — {"states": {"idle": [[...14 strings]...]},
//                       "palette": {"R": "#e8593d"}}
// Estados/cores ausentes caem no padrão. Grades inválidas são ignoradas.
// ---------------------------------------------------------------------------

var customFrames: [String: [[String]]] = [:]
var customPalette: [Character: NSColor] = [:]

func isValidFrame(_ frame: [String]) -> Bool {
    frame.count == gridRows && frame.allSatisfy { $0.count == gridCols }
}

func colorFromHex(_ hex: String) -> NSColor? {
    var h = hex.trimmingCharacters(in: .whitespaces)
    if h.hasPrefix("#") { h.removeFirst() }
    guard h.count == 6, let v = UInt32(h, radix: 16) else { return nil }
    return NSColor(
        red: CGFloat((v >> 16) & 0xFF) / 255,
        green: CGFloat((v >> 8) & 0xFF) / 255,
        blue: CGFloat(v & 0xFF) / 255,
        alpha: 1.0)
}

struct SpritePack: Codable {
    var states: [String: [[String]]]?
    var palette: [String: String]?
}

func loadCustomSprites(from url: URL) {
    guard let data = try? Data(contentsOf: url),
          let pack = try? JSONDecoder().decode(SpritePack.self, from: data)
    else { return }
    for (state, frames) in pack.states ?? [:] {
        guard PetState(rawValue: state) != nil, !frames.isEmpty,
              frames.allSatisfy(isValidFrame)
        else {
            NSLog("craby: sprites.json — estado \"%@\" inválido, ignorado", state)
            continue
        }
        customFrames[state] = frames
    }
    for (key, hex) in pack.palette ?? [:] {
        guard let ch = key.first, key.count == 1, let color = colorFromHex(hex) else { continue }
        customPalette[ch] = color
    }
}

func paletteColor(_ ch: Character) -> NSColor? {
    customPalette[ch] ?? defaultPalette[ch]
}

// ---------------------------------------------------------------------------
// Estados
// ---------------------------------------------------------------------------

enum PetState: String, CaseIterable {
    case idle, working, done, attention, sleeping

    // a arte de cada estado agora nasce do motor de cenas+props (Scenes.swift)
    var frames: [[String]] {
        if let custom = customFrames[rawValue] { return custom }
        return composedFrames(for: self)
    }

    var interval: TimeInterval {
        switch self {
        case .idle: return 0.8
        case .working: return 0.2
        case .done: return 0.4
        case .attention: return 0.35
        case .sleeping: return 1.2
        }
    }

    // prioridade de exibição quando há várias sessões
    var priority: Int {
        switch self {
        case .attention: return 3
        case .working: return 2
        case .done: return 1
        case .idle, .sleeping: return 0
        }
    }
}

// manias espontâneas do ócio: sequências curtas de quadros tocadas uma vez
let idleQuirks: [[[String]]] = [
    // aceninho
    [emptyFx + waveV2, emptyFx + idleV2a, emptyFx + waveV2],
    // passinho de lado
    [
        emptyFx + shifted(idleV2b, dx: 1),
        emptyFx + shifted(idleV2a, dx: 1),
        emptyFx + shifted(idleV2b, dx: -1),
        emptyFx + shifted(idleV2a, dx: -1),
        emptyFx + idleV2a,
    ],
    // bolhinha subindo
    [
        ["..............", "..............", "......C.......", ".............."] + idleV2a,
        ["..............", "......C.......", "..............", ".............."] + idleV2a,
        ["......C.......", "..............", "..............", ".............."] + idleV2a,
    ],
]

// festa (/celebrate): cena comemorando + prop confete, 3 ciclos
let levelUpFrames: [[String]] = (0..<6).map {
    compose(scene: sceneComemorando, props: [propConfete], frame: $0)
}

func drawGrid(_ grid: [String], pixel: CGFloat, height: CGFloat) {
    for (row, line) in grid.enumerated() {
        for (col, ch) in line.enumerated() {
            guard let color = paletteColor(ch) else { continue }
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
