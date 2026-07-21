import AppKit

// CLI de renderização: gera o ícone e os quadros do GIF de demonstração
// a partir das MESMAS grades de sprites do app (Sources/Sprites.swift).
// Uso: render icon <saida.png>
//      render frames <pasta>    (quadros 001.png... a 10 fps para o GIF)

func render(_ grid: [String], pixel: Int, canvas: Int? = nil) -> NSBitmapImageRep {
    let rows = grid.count
    let cols = grid.first?.count ?? 0
    let w = canvas ?? cols * pixel
    let h = canvas ?? rows * pixel
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let offX = (w - cols * pixel) / 2
    let offY = (h - rows * pixel) / 2
    for (row, line) in grid.enumerated() {
        for (col, ch) in line.enumerated() {
            guard let color = paletteColor(ch) else { continue }
            color.setFill()
            NSRect(
                x: offX + col * pixel, y: h - offY - (row + 1) * pixel,
                width: pixel, height: pixel
            ).fill()
        }
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(_ rep: NSBitmapImageRep, to path: String) {
    guard let data = rep.representation(using: .png, properties: [:]) else {
        fputs("erro ao gerar PNG\n", stderr)
        exit(1)
    }
    do { try data.write(to: URL(fileURLWithPath: path)) } catch {
        fputs("erro ao escrever \(path): \(error)\n", stderr)
        exit(1)
    }
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("uso: render icon <saida.png> | render frames <pasta>")
    exit(1)
}

switch args[1] {
case "icon":
    // ícone: só o caranguejo (sem a área de efeitos), centralizado em 1024px
    writePNG(render(clawsUp, pixel: 64, canvas: 1024), to: args[2])
    print("icone gerado")

case "frames":
    let dir = args[2]
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    // roteiro do GIF a 10 fps: (estado, ciclos da animação)
    let script: [(PetState, Int)] = [(.idle, 1), (.working, 6), (.done, 4), (.attention, 3)]
    var n = 0
    for (state, cycles) in script {
        let ticksPerFrame = max(1, Int(state.interval * 10))
        for _ in 0..<cycles {
            for frame in state.frames {
                let rep = render(frame, pixel: 10)
                for _ in 0..<ticksPerFrame {
                    n += 1
                    writePNG(rep, to: "\(dir)/\(String(format: "%03d", n)).png")
                }
            }
        }
    }
    print(n)

default:
    print("modo desconhecido: \(args[1])")
    exit(1)
}
