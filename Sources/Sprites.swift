import AppKit

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

let defaultPalette: [Character: NSColor] = [
    "R": NSColor(red: 0.91, green: 0.35, blue: 0.24, alpha: 1.0),
    "D": NSColor(red: 0.72, green: 0.22, blue: 0.14, alpha: 1.0),
    "W": .white,
    "B": .black,
    "Y": NSColor(red: 1.0, green: 0.82, blue: 0.15, alpha: 1.0),
    "G": NSColor(red: 0.35, green: 0.39, blue: 0.45, alpha: 1.0),
    "L": NSColor(red: 0.60, green: 0.65, blue: 0.71, alpha: 1.0),
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
    case idle, working, done, attention

    var frames: [[String]] {
        if let custom = customFrames[rawValue] { return custom }
        switch self {
        case .idle:
            return [
                emptyFx + clawsUp,
                emptyFx + clawsDown,
                emptyFx + clawsUp,
                emptyFx + blinking(clawsDown),
            ]
        case .working:
            return [laptopLeft, laptopRight]
        case .done:
            return [sparkleFx1 + clawsUp, jumping(sparkleFx2, clawsUp)]
        case .attention:
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
