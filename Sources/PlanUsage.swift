import Foundation
import Security

// ---------------------------------------------------------------------------
// Uso do plano Claude (janelas de 5h/semana): mesmo endpoint OAuth que o
// /usage do Claude Code consulta. Se não houver token, o recurso simplesmente
// não aparece — nada quebra. O token nunca é gravado nem logado.
// Ordem de busca: env CLAUDE_CODE_OAUTH_TOKEN -> ~/.claude/.credentials.json
// -> arquivo do Craby (Application Support/Craby/oauth-token, p/ quem gera
// com `claude setup-token`) -> Keychain (por último: pode pedir permissão).
// ---------------------------------------------------------------------------

struct PlanWindow {
    let key: String        // five_hour / seven_day / seven_day_opus / ...
    let utilization: Double // 0-100
    let resetsAt: Date?
}

final class PlanUsageClient {
    static func loadToken() -> String? {
        if let env = ProcessInfo.processInfo.environment["CLAUDE_CODE_OAUTH_TOKEN"],
           !env.isEmpty {
            return env
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent(".claude/.credentials.json"),
            home.appendingPathComponent(
                "Library/Application Support/Craby/oauth-token"),
        ]
        for url in candidates {
            if let data = try? Data(contentsOf: url), let token = parseToken(data) {
                return token
            }
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data {
            return parseToken(data)
        }
        return nil
    }

    static func parseToken(_ data: Data) -> String? {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let oauth = obj["claudeAiOauth"] as? [String: Any],
               let token = oauth["accessToken"] as? String {
                return token
            }
            return nil
        }
        // arquivo com o token puro (saída do `claude setup-token`)
        let raw = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (raw?.isEmpty == false) ? raw : nil
    }

    func fetch(completion: @escaping ([PlanWindow]?) -> Void) {
        guard let token = Self.loadToken() else {
            completion(nil)
            return
        }
        var request = URLRequest(
            url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, response, _ in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 200, let data, let windows = Self.parseWindows(data) {
                completion(windows)
                return
            }
            if status == 401 { completion(nil); return }
            // o edge da Anthropic pode recusar o TLS de algumas libs; curl passa
            Self.curlFallback(token: token, completion: completion)
        }.resume()
    }

    private static func curlFallback(
        token: String, completion: @escaping ([PlanWindow]?) -> Void
    ) {
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            process.arguments = [
                "-s", "-m", "15",
                "-H", "Authorization: Bearer \(token)",
                "-H", "anthropic-beta: oauth-2025-04-20",
                "https://api.anthropic.com/api/oauth/usage",
            ]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                completion(parseWindows(data))
            } catch {
                completion(nil)
            }
        }
    }

    // parse defensivo: qualquer chave cujo valor tenha "utilization" vira janela
    static func parseWindows(_ data: Data) -> [PlanWindow]? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let iso = ISO8601DateFormatter()

        var out: [PlanWindow] = []
        for (key, value) in obj {
            guard let dict = value as? [String: Any] else { continue }
            let util: Double?
            if let d = dict["utilization"] as? Double { util = d }
            else if let i = dict["utilization"] as? Int { util = Double(i) }
            else { util = nil }
            guard let utilization = util else { continue }
            var resets: Date?
            if let r = dict["resets_at"] as? String {
                resets = isoFrac.date(from: r) ?? iso.date(from: r)
            }
            out.append(PlanWindow(key: key, utilization: utilization, resetsAt: resets))
        }
        guard !out.isEmpty else { return nil }
        let order = ["five_hour": 0, "seven_day": 1, "seven_day_opus": 2]
        return out.sorted { (order[$0.key] ?? 9) < (order[$1.key] ?? 9) }
    }
}
