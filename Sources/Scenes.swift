import Foundation

// ---------------------------------------------------------------------------
// Motor de CENAS + PROPS + SLOTS (v2)
//
// Cena  = pose do corpo (quadros completos 14x14) + slots de ancoragem.
// Prop  = grade pequena carimbada num slot ("." é transparente).
// Slot  = posição POR QUADRO (âncora acompanha o corpo), tamanho máximo.
//
// Regras: prop apenas translada (nunca rotaciona); prop tem 1 quadro
// (estático) ou o nº de quadros da cena (sincronizado); prop inválido ou
// grande demais é ignorado — o pet nunca quebra por causa de um addon.
// ---------------------------------------------------------------------------

struct SceneSlot {
    let pos: [(x: Int, y: Int)] // uma âncora por quadro da cena
    let maxW: Int
    let maxH: Int
}

struct Scene {
    let name: String
    let frames: [[String]]
    let slots: [String: SceneSlot]
}

struct Prop {
    let name: String
    let slot: String
    let frames: [[String]] // 1 (estático) ou nº de quadros da cena
}

// carimba a grade pequena sobre a grande; "." não pinta
func stamp(_ small: [String], onto grid: [String], x: Int, y: Int) -> [String] {
    var g = grid.map { Array($0) }
    for (r, row) in small.enumerated() {
        for (c, ch) in row.enumerated() where ch != "." {
            let rr = y + r
            let cc = x + c
            guard rr >= 0, rr < g.count, cc >= 0, cc < g[rr].count else { continue }
            g[rr][cc] = ch
        }
    }
    return g.map { String($0) }
}

// compõe um quadro: cena + props nos slots (âncora do quadro corrente)
func compose(scene: Scene, props: [Prop], frame: Int) -> [String] {
    guard !scene.frames.isEmpty else { return [] }
    let i = frame % scene.frames.count
    var grid = scene.frames[i]
    for prop in props {
        guard let slot = scene.slots[prop.slot], !prop.frames.isEmpty else { continue }
        let propGrid = prop.frames[i % prop.frames.count]
        guard propGrid.count <= slot.maxH,
              propGrid.allSatisfy({ $0.count <= slot.maxW })
        else { continue }
        let anchor = slot.pos[i % slot.pos.count]
        grid = stamp(propGrid, onto: grid, x: anchor.x, y: anchor.y)
    }
    return grid
}

// ---------------------------------------------------------------------------
// Catálogo de cenas (arte atual migrada tal-qual; refresh visual vem depois)
// Âncoras "cabeça" ficam declaradas para os addons do futuro.
// ---------------------------------------------------------------------------

let sceneIdle = Scene(
    name: "idle",
    frames: [
        emptyFx + clawsUp,
        emptyFx + clawsDown,
        emptyFx + clawsUp,
        emptyFx + blinking(clawsDown),
    ],
    slots: [
        "cabeca": SceneSlot(pos: [(2, 1), (2, 1), (2, 1), (2, 1)], maxW: 10, maxH: 2)
    ])

// debruçado no laptop — o laptop agora é um PROP no slot "mesa"
let sceneDebrucado = Scene(
    name: "debrucado",
    frames: [
        // corpo digitando (tecla voando faz parte da cena; a mesa fica vazia)
        [
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
            "..............",
            "..............",
            "..............",
            "..............",
        ],
        [
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
            "..............",
            "..............",
            "..............",
            "..............",
        ],
    ],
    slots: [
        "mesa": SceneSlot(pos: [(2, 10), (2, 10)], maxW: 10, maxH: 3),
        "cabeca": SceneSlot(pos: [(2, 2), (2, 2)], maxW: 10, maxH: 2),
    ])

// comemorando: pulinhos — brilhos/confete são props no slot "ceu"
let sceneComemorando = Scene(
    name: "comemorando",
    frames: [
        emptyFx + clawsUp,
        jumping(emptyFx, clawsUp),
    ],
    slots: [
        // 3 linhas: no quadro do pulo o corpo sobe e ocupa a 4ª linha do céu
        "ceu": SceneSlot(pos: [(0, 0), (0, 0)], maxW: 14, maxH: 3),
        "cabeca": SceneSlot(pos: [(2, 3), (2, 2)], maxW: 10, maxH: 2),
    ])

// deitado dormindo — o "Zzz" é um prop no slot "acima"
let sceneDeitado = Scene(
    name: "deitado",
    frames: [
        emptyFx + blinking(clawsDown),
        emptyFx + blinking(clawsDown),
    ],
    slots: [
        "acima": SceneSlot(pos: [(0, 0), (0, 0)], maxW: 14, maxH: 4),
        "cabeca": SceneSlot(pos: [(2, 3), (2, 3)], maxW: 10, maxH: 2),
    ])

// atenção: acenando — cara única global, sem slots de addon
let sceneAtencao = Scene(
    name: "atencao",
    frames: [
        exclaimFx + clawsUp,
        emptyFx + rightUpLeftDown,
        exclaimFx + clawsUp,
        emptyFx + leftUpRightDown,
    ],
    slots: [
        "cabeca": SceneSlot(pos: [(2, 3), (2, 3), (2, 3), (2, 3)], maxW: 10, maxH: 2)
    ])

// ---------------------------------------------------------------------------
// Props do app
// ---------------------------------------------------------------------------

let propLaptop = Prop(
    name: "laptop", slot: "mesa",
    frames: [[
        "GGGGGGGGGG",
        "GLLLLLLLLG",
        "GGGGGGGGGG",
    ]])

let propZzz = Prop(name: "zzz", slot: "acima", frames: [sleepFx1, sleepFx2])

let propBrilhos = Prop(
    name: "brilhos", slot: "ceu",
    frames: [Array(sparkleFx1.prefix(3)), Array(sparkleFx2.prefix(3))])

let propConfete = Prop(
    name: "confete", slot: "ceu",
    frames: [Array(confettiFx1.prefix(3)), Array(confettiFx2.prefix(3))])

// ---------------------------------------------------------------------------
// Mapeamento estado -> cena + props (a arte final de cada estado)
// ---------------------------------------------------------------------------

func composedFrames(for state: PetState) -> [[String]] {
    switch state {
    case .idle:
        return (0..<sceneIdle.frames.count).map {
            compose(scene: sceneIdle, props: [], frame: $0)
        }
    case .working:
        return (0..<sceneDebrucado.frames.count).map {
            compose(scene: sceneDebrucado, props: [propLaptop], frame: $0)
        }
    case .done:
        return (0..<sceneComemorando.frames.count).map {
            compose(scene: sceneComemorando, props: [propBrilhos], frame: $0)
        }
    case .attention:
        return (0..<sceneAtencao.frames.count).map {
            compose(scene: sceneAtencao, props: [], frame: $0)
        }
    case .sleeping:
        return (0..<sceneDeitado.frames.count).map {
            compose(scene: sceneDeitado, props: [propZzz], frame: $0)
        }
    }
}
