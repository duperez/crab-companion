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

check(isValidFrame(blinking(emptyFx + clawsDown)), "piscada preserva a grade")
check(isValidFrame(jumping(sparkleFx2, clawsUp)), "pulo preserva a grade")

// --- olhos e acessórios ---

check(eyesLooking(left: true, [".RRWBRRRRWBRR."]) == [".RRBWRRRRBWRR."],
      "olhos: pupilas viram para a esquerda")
check(eyesLooking(left: false, [".RRWBRRRRWBRR."]) == [".RRWBRRRRWBRR."],
      "olhos: direita mantém a arte original")

for level in [1, 3, 5, 6, 99] {
    for state in PetState.allCases {
        for (i, frame) in state.frames.enumerated() {
            check(isValidFrame(overlayAccessory(frame, level: level)),
                  "acessório nível \(level): \(state.rawValue) quadro \(i) continua 14x14")
        }
    }
}
check(overlayAccessory(emptyFx + clawsUp, level: 1) == emptyFx + clawsUp,
      "acessório: nível baixo não altera a arte")
check(overlayAccessory(emptyFx + clawsUp, level: 6) != emptyFx + clawsUp,
      "acessório: coroa altera a arte")

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

// --- resultado ---

print(failures == 0 ? "\ntodos os testes passaram" : "\n\(failures) falha(s)")
exit(failures == 0 ? 0 : 1)
