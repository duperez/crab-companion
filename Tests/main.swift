import Foundation

// Testes do Craby: grades de sprites e parser HTTP.
// Compilar e rodar:
//   swiftc Sources/Sprites.swift Sources/HTTPServer.swift Sources/L10n.swift \
//     Tests/main.swift -o run_tests && ./run_tests

var failures = 0

func check(_ condition: Bool, _ name: String) {
    if condition {
        print("ok   - \(name)")
    } else {
        failures += 1
        print("FAIL - \(name)")
    }
}

// --- sprites: todo estado tem quadros e todos são 14x14 ---

for state in PetState.allCases {
    check(!state.frames.isEmpty, "\(state.rawValue): tem quadros")
    for (i, frame) in state.frames.enumerated() {
        check(isValidFrame(frame), "\(state.rawValue) quadro \(i): grade \(gridRows)x\(gridCols)")
    }
    check(state.interval > 0, "\(state.rawValue): intervalo positivo")
}

check(isValidFrame(blinking(emptyFx + idleV2a)), "piscada preserva a grade")
check(isValidFrame(jumping(sparkleFx2, idleV2a)), "pulo preserva a grade")

// --- olhos e acessórios ---

check(eyesLooking(left: true, [".RRWBRRRRWBRR."]) == [".RRBWRRRRBWRR."],
      "olhos: pupilas viram para a esquerda")
check(eyesLooking(left: false, [".RRWBRRRRWBRR."]) == [".RRWBRRRRWBRR."],
      "olhos: direita mantém a arte original")

// --- motor de cenas + props + slots ---

for state in PetState.allCases {
    for (i, frame) in state.frames.enumerated() {
        check(isValidFrame(frame), "cena \(state.rawValue): quadro \(i) é 14x14 válido")
    }
}

let working0 = compose(scene: sceneDebrucado, props: [propLaptop], frame: 0)
check(working0[11].contains("LLLLLLLL"), "prop laptop carimbado no slot mesa")
check(working0[10].hasPrefix("..R"), "mãozinha digitando fica NA FRENTE do laptop")
check(working0[10].contains("GGG"), "laptop aparece atrás da mãozinha")
check(!compose(scene: sceneDebrucado, props: [], frame: 0)[11].contains("L"),
      "cena debruçado sem prop tem a mesa vazia")

// prop maior que o slot é ignorado sem quebrar a cena
let gigante = Prop(name: "g", slot: "ceu", frames: [Array(repeating: "YYYY", count: 9)])
check(compose(scene: sceneComemorando, props: [gigante], frame: 0)
      == compose(scene: sceneComemorando, props: [], frame: 0),
      "prop grande demais é ignorado")

// prop em slot inexistente na cena é ignorado
let semSlot = Prop(name: "x", slot: "inexistente", frames: [["Y"]])
check(compose(scene: sceneIdle, props: [semSlot], frame: 0)
      == compose(scene: sceneIdle, props: [], frame: 0),
      "prop de slot inexistente é ignorado")

// carimbo fora dos limites não estoura
check(stamp(["YY", "YY"], onto: emptyFx, x: 13, y: 3).count == emptyFx.count,
      "stamp na borda não quebra a grade")

// âncora por quadro: prop translada junto com o corpo
let cenaTeste = Scene(
    name: "t", frames: [emptyFx + idleV2a, emptyFx + idleV2a],
    slots: ["s": SceneSlot(pos: [(0, 0), (2, 0)], maxW: 3, maxH: 1)])
let pontinho = Prop(name: "p", slot: "s", frames: [["Y"]])
check(compose(scene: cenaTeste, props: [pontinho], frame: 0)[0].hasPrefix("Y"),
      "âncora do quadro 0")
check(compose(scene: cenaTeste, props: [pontinho], frame: 1)[0].hasPrefix("..Y"),
      "âncora do quadro 1 (prop transladou)")

// --- filhotes (ninhada de subagentes) ---

let babyFrames: [(String, [String])] = [
    ("ovo", babyEgg), ("ovo rachando", babyEggCracking),
    ("vivo 1", babyAlive1), ("vivo 2", babyAlive2),
    ("bengala", babyElderly), ("puf 1", babyPoof1), ("puf 2", babyPoof2),
]
for (name, frame) in babyFrames {
    check(isValidBabyFrame(frame), "filhote \(name): grade \(babyRows)x\(babyCols)")
}
check(isValidBabyFrame(failedRecolor(babyPoof1)), "puf de erro preserva a grade")
check(failedRecolor(babyPoof1) != babyPoof1, "puf de erro muda as cores")

// --- prioridade de estados ---

check(PetState.attention.priority > PetState.working.priority, "attention > working")
check(PetState.working.priority > PetState.done.priority, "working > done")
check(PetState.done.priority > PetState.idle.priority, "done > idle")

// --- cores ---

check(colorFromHex("#e8593d") != nil, "hex com # aceito")
check(colorFromHex("e8593d") != nil, "hex sem # aceito")
check(colorFromHex("xyz") == nil, "hex inválido rejeitado")
for ch in "RDWBYGL" {
    check(paletteColor(ch) != nil, "palette tem \(ch)")
}

// --- parser HTTP ---

func req(_ raw: String) -> HTTPRequest? {
    ControlServer.parse(raw.data(using: .utf8)!)
}

let get = req("GET /working?session=abc&project=p%20x HTTP/1.1\r\nHost: h\r\n\r\n")
check(get?.method == "GET", "GET: método")
check(get?.path == "/working", "GET: caminho sem query")
check(get?.query["session"] == "abc", "GET: query session")
check(get?.query["project"] == "p x", "GET: percent-decoding no project")

let headers = req("GET /answer/allow HTTP/1.1\r\nX-Craby-Token: s3cret\r\n\r\n")
check(headers?.headers["x-craby-token"] == "s3cret", "headers: lidos em minúsculas")

let partial = "POST /ask HTTP/1.1\r\nContent-Length: 10\r\n\r\nabc"
check(req(partial) == nil, "POST: corpo incompleto aguarda mais dados")

let full = req("POST /ask HTTP/1.1\r\nContent-Length: 4\r\n\r\nbody")
check(full?.method == "POST", "POST: método")
check(full.map { String(data: $0.body, encoding: .utf8) } == "body", "POST: corpo completo")

let payload = """
{"title":"t","detail":"d","urgent":false,"options":["a","b"],"input":null}
"""
let decoded = try? JSONDecoder().decode(AskPayload.self, from: payload.data(using: .utf8)!)
check(decoded?.options?.count == 2, "AskPayload: decodifica options")
check(decoded?.input == nil, "AskPayload: input nulo vira nil")

// --- temas de som ---

for (theme, map) in soundThemes {
    for event in SoundEvent.allCases {
        check(map[event] != nil, "tema \(theme): tem som para \(event.rawValue)")
    }
}
check(soundName(event: .done, theme: "inexistente", overrides: nil) == "Glass",
      "tema desconhecido cai no classic")
check(soundName(event: .done, theme: "classic", overrides: ["done": "Hero"]) == "Hero",
      "override individual vence o tema")

// --- compatibilidade de stats antigos (sem maxBrood) ---

let oldDay = "{\"tasks\":3,\"projects\":[\"x\"],\"workSeconds\":10}"
let decodedDay = try? JSONDecoder().decode(DayStats.self, from: oldDay.data(using: .utf8)!)
check(decodedDay?.tasks == 3, "DayStats antigo decodifica sem maxBrood")
check(decodedDay?.maxBrood == nil, "maxBrood ausente vira nil")

// --- balão de permissão: regra do "Sempre permitir" ---

let rulePayload = """
{"title":"t","detail":"d","urgent":false,"options":null,"input":null,"rule":"Bash(git *)"}
"""
let decodedRule = try? JSONDecoder().decode(
    AskPayload.self, from: rulePayload.data(using: .utf8)!)
check(decodedRule?.rule == "Bash(git *)", "AskPayload: decodifica rule")

let noRulePayload = """
{"title":"t","detail":"d","urgent":false,"options":null,"input":null}
"""
let decodedNoRule = try? JSONDecoder().decode(
    AskPayload.self, from: noRulePayload.data(using: .utf8)!)
check(decodedNoRule != nil, "AskPayload: payload antigo sem rule ainda decodifica")
check(decodedNoRule?.rule == nil, "AskPayload: rule ausente vira nil")

// --- uso do plano: parse defensivo do endpoint OAuth ---

let planJSON = """
{"five_hour":{"utilization":84,"resets_at":"2026-07-22T16:32:00Z"},
 "seven_day":{"utilization":31.5,"resets_at":"2026-07-25T00:00:00Z"},
 "extra_field":"ignorado"}
"""
let windows = PlanUsageClient.parseWindows(planJSON.data(using: .utf8)!)
check(windows?.count == 2, "plano: extrai as duas janelas e ignora o resto")
check(windows?.first?.key == "five_hour", "plano: five_hour vem primeiro")
check(windows?.first?.utilization == 84, "plano: utilization inteira vira Double")
check(windows?.first?.resetsAt != nil, "plano: resets_at ISO8601 parseia")
check(PlanUsageClient.parseWindows(Data("nada".utf8)) == nil,
      "plano: resposta inválida vira nil")
check(PlanUsageClient.parseWindows(Data("{}".utf8)) == nil,
      "plano: sem janelas vira nil")

let tokenJSON = """
{"claudeAiOauth":{"accessToken":"sk-teste-123"}}
"""
check(PlanUsageClient.parseToken(tokenJSON.data(using: .utf8)!) == "sk-teste-123",
      "plano: token extraído do credentials.json")
check(PlanUsageClient.parseToken(Data("  sk-cru-456\n".utf8)) == "sk-cru-456",
      "plano: arquivo com token puro funciona")

// --- L10n das novidades ---

check(!L.alwaysAllow.isEmpty, "L10n: alwaysAllow existe")
check(L.plan5h(84, reset: "16:32").contains("84"), "L10n: plan5h mostra o percentual")
check(!L.pushParty.isEmpty, "L10n: pushParty existe")

// --- resultado ---

print(failures == 0 ? "\ntodos os testes passaram" : "\n\(failures) falha(s)")
exit(failures == 0 ? 0 : 1)
