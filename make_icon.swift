// Gera o PNG 1024x1024 do ícone a partir da pixel art do caranguejo.
// Uso: swift make_icon.swift <saida.png>
import AppKit

let crab = [
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

let palette: [Character: NSColor] = [
    "R": NSColor(red: 0.91, green: 0.35, blue: 0.24, alpha: 1.0),
    "D": NSColor(red: 0.72, green: 0.22, blue: 0.14, alpha: 1.0),
    "W": .white,
    "B": .black,
]

let canvas = 1024
let cols = 14
let rows = crab.count
let pixel = 64 // 14 col * 64 = 896, sobra margem
let offsetX = (canvas - cols * pixel) / 2
let offsetY = (canvas - rows * pixel) / 2

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: canvas, pixelsHigh: canvas,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

for (row, line) in crab.enumerated() {
    for (col, ch) in line.enumerated() {
        guard let color = palette[ch] else { continue }
        color.setFill()
        NSRect(
            x: offsetX + col * pixel,
            y: canvas - offsetY - (row + 1) * pixel,
            width: pixel, height: pixel
        ).fill()
    }
}

NSGraphicsContext.restoreGraphicsState()

let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("icone gerado")
