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

case "promo":
    // GIF promocional: Craby + ninhada num ciclo completo (10 fps)
    let dir = args[2]
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let px: CGFloat = 12
    let cols = 24
    let rowsTotal = 21 // 14 do Craby + 1 de respiro + 6 da ninhada

    func crabGridFor(_ t: Int) -> [String] {
        switch t {
        case 0..<16: // ocioso
            return emptyFx + [clawsUp, clawsDown, clawsUp, blinking(clawsDown)][(t / 4) % 4]
        case 16..<48: // trabalhando no laptop (cena debruçado + prop laptop)
            return compose(
                scene: sceneDebrucado, props: [propLaptop], frame: (t % 4 < 2) ? 0 : 1)
        case 48..<64: // comemorando
            return (t % 8 < 4) ? sparkleFx1 + clawsUp : jumping(sparkleFx2, clawsUp)
        default: // atenção
            return [exclaimFx + clawsUp, emptyFx + rightUpLeftDown,
                    exclaimFx + clawsUp, emptyFx + leftUpRightDown][(t / 3) % 4]
        }
    }

    func babyGridFor(_ t: Int, spawn: Int, retire: Int, failed: Bool) -> [String]? {
        if t < spawn { return nil }
        let age = t - spawn
        if age < 2 { return babyEgg }
        if age < 4 { return babyEggCracking }
        if t < retire { return (age % 4 < 2) ? babyAlive1 : babyAlive2 }
        let r = t - retire
        if r < 6 { return babyElderly }
        if r < 8 {
            let grid = r < 7 ? babyPoof1 : babyPoof2
            return failed ? failedRecolor(grid) : grid
        }
        return nil
    }

    let spawns = [16, 20, 24]
    let retires = [48, 50, 52]
    var count = 0
    for t in 0..<78 {
        let w = Int(CGFloat(cols) * px)
        let h = Int(CGFloat(rowsTotal) * px)
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let viewH = CGFloat(rowsTotal) * px
        drawGridAt(crabGridFor(t), pixel: px, viewHeight: viewH, originX: 5 * px, topY: 0)
        for i in 0..<3 {
            if let grid = babyGridFor(t, spawn: spawns[i], retire: retires[i], failed: i == 1) {
                drawGridAt(grid, pixel: px, viewHeight: viewH,
                           originX: CGFloat(i * 8) * px + px / 2, topY: 15 * px)
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        count += 1
        writePNG(rep, to: "\(dir)/\(String(format: "%03d", count)).png")
    }
    print(count)

default:
    print("modo desconhecido: \(args[1])")
    exit(1)
}
