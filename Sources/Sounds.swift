import Foundation

// ---------------------------------------------------------------------------
// Temas de som: cada evento do Craby tem um som por tema.
// Override individual via config.json: {"soundPack": {"done": "Hero", ...}}
// ---------------------------------------------------------------------------

enum SoundEvent: String, CaseIterable {
    case done, attention, hatch, poofOk, poofFail, levelUp
}

let soundThemes: [String: [SoundEvent: String]] = [
    "classic": [
        .done: "Glass", .attention: "Ping", .hatch: "Pop",
        .poofOk: "Tink", .poofFail: "Basso", .levelUp: "Funk",
    ],
    "soft": [
        .done: "Purr", .attention: "Tink", .hatch: "Pop",
        .poofOk: "Purr", .poofFail: "Bottle", .levelUp: "Glass",
    ],
    "retro": [
        .done: "Hero", .attention: "Sosumi", .hatch: "Morse",
        .poofOk: "Pop", .poofFail: "Basso", .levelUp: "Funk",
    ],
]

let soundThemeOrder = ["classic", "soft", "retro"]

func soundName(event: SoundEvent, theme: String?, overrides: [String: String]?) -> String {
    if let custom = overrides?[event.rawValue] { return custom }
    let themeMap = soundThemes[theme ?? "classic"] ?? soundThemes["classic"]!
    return themeMap[event] ?? "Glass"
}
