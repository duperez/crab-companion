import AppKit

// ---------------------------------------------------------------------------
// Addons: pasta com addon.json + executável. O Craby é o SUPERVISOR:
// descobre, liga/desliga pelo menu e roda o exec a cada `interval` segundos.
// O figurino (cena + props) vem declarado no manifesto — dado, não código.
// Addons avisam e perguntam pela API local; nunca recebem o token.
// ---------------------------------------------------------------------------

struct AddonManifest: Codable {
    let name: String
    let exec: String
    var description: String?
    var source: String?          // identidade na sourcePriority (padrão: name)
    var interval: Double?        // segundos entre execuções (padrão 30, mín 5)
    var scene: String?           // cena do catálogo (padrão "atento")
    var props: [String: [String]]?  // slot -> grid
    var cores: [String: String]?    // caractere -> #hex
}

struct LoadedAddon {
    let dir: URL
    let manifest: AddonManifest
    var sourceName: String { manifest.source ?? manifest.name }
}

final class AddonManager {
    private(set) var addons: [LoadedAddon] = []
    private var timers: [String: Timer] = [:]

    // pastas escaneadas: Resources/addons (embutidos), Application Support/
    // Craby/addons (do usuário) e ./addons ao lado do binário (dev)
    private var searchDirs: [URL] {
        var dirs: [URL] = []
        if let res = Bundle.main.resourceURL {
            dirs.append(res.appendingPathComponent("addons"))
        }
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Craby/addons")
        try? FileManager.default.createDirectory(
            at: support, withIntermediateDirectories: true)
        dirs.append(support)
        let binDir = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent().appendingPathComponent("addons")
        dirs.append(binDir)
        return dirs
    }

    var userAddonsDir: URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Craby/addons")
    }

    func scan() {
        var found: [LoadedAddon] = []
        var seen = Set<String>()
        for dir in searchDirs {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil) else { continue }
            for entry in entries {
                let manifestURL = entry.appendingPathComponent("addon.json")
                guard let data = try? Data(contentsOf: manifestURL),
                      let manifest = try? JSONDecoder().decode(
                        AddonManifest.self, from: data),
                      !seen.contains(manifest.name)
                else { continue }
                seen.insert(manifest.name)
                found.append(LoadedAddon(dir: entry, manifest: manifest))
                // cores novas do addon entram na paleta compartilhada
                for (key, hex) in manifest.cores ?? [:] {
                    if let ch = key.first, key.count == 1,
                       let color = colorFromHex(hex) {
                        customPalette[ch] = color
                    }
                }
            }
        }
        addons = found.sorted { $0.manifest.name < $1.manifest.name }
        syncTimers()
    }

    func isEnabled(_ addon: LoadedAddon) -> Bool {
        UserDefaults.standard.bool(forKey: "addon.\(addon.manifest.name)")
    }

    func setEnabled(_ addon: LoadedAddon, _ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "addon.\(addon.manifest.name)")
        syncTimers()
    }

    private func syncTimers() {
        for (name, timer) in timers
        where !addons.contains(where: { $0.manifest.name == name && isEnabled($0) }) {
            timer.invalidate()
            timers.removeValue(forKey: name)
        }
        for addon in addons where isEnabled(addon) && timers[addon.manifest.name] == nil {
            let interval = max(5, addon.manifest.interval ?? 30)
            let timer = Timer.scheduledTimer(
                withTimeInterval: interval, repeats: true
            ) { [weak self] _ in self?.run(addon) }
            timers[addon.manifest.name] = timer
            run(addon) // primeira execução imediata ao ligar
        }
    }

    // roda o exec do addon (uma execução: dispara eventos via API e sai)
    private func run(_ addon: LoadedAddon) {
        let exec = addon.dir.appendingPathComponent(addon.manifest.exec)
        guard FileManager.default.isExecutableFile(atPath: exec.path) else {
            NSLog("craby: addon %@ sem executável válido", addon.manifest.name)
            return
        }
        let process = Process()
        process.executableURL = exec
        process.currentDirectoryURL = addon.dir
        var env = ProcessInfo.processInfo.environment
        env["CRABY_PORT"] = "4923"
        env["CRABY_SOURCE"] = addon.sourceName
        process.environment = env
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        // watchdog: mata execuções penduradas depois de 60s
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 60) {
            if process.isRunning { process.terminate() }
        }
    }

    // figurino do addon vencedor: cena escolhida + props declarados
    func outfit(for source: String) -> (scene: Scene, props: [Prop])? {
        guard let addon = addons.first(where: { $0.sourceName == source }),
              let declared = addon.manifest.props, !declared.isEmpty
        else { return nil }
        let scene: Scene
        switch addon.manifest.scene {
        case "debrucado": scene = sceneDebrucado
        default: scene = sceneAtento
        }
        let props = declared.map { slot, grid in
            Prop(name: "\(addon.manifest.name)-\(slot)", slot: slot, frames: [grid])
        }
        return (scene, props)
    }
}
