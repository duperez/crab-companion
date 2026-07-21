import Foundation

// Idioma: português se o sistema estiver em pt-*, inglês caso contrário.
let isPortuguese = Locale.preferredLanguages.first?.lowercased().hasPrefix("pt") ?? false

func tr(_ en: String, _ pt: String) -> String { isPortuguese ? pt : en }

enum L {
    static var allow: String { tr("Allow", "Permitir") }
    static var deny: String { tr("Deny", "Negar") }
    static var terminal: String { tr("Terminal", "Terminal") }
    static var answerInTerminal: String { tr("Answer in the terminal", "Responder no terminal") }
    static var send: String { tr("Send", "Enviar") }
    static var typeAnswer: String { tr("Type your answer…", "Digite sua resposta…") }
    static var collapseToBar: String { tr("Collapse to menu bar", "Recolher para a barra") }
    static var showFloating: String { tr("Show floating Craby", "Mostrar flutuante") }
    static var sounds: String { tr("Sounds", "Sons") }
    static var quit: String { tr("Quit", "Sair") }
    static var resetPosition: String { tr("Reset position", "Redefinir posição") }
    static var recentEvents: String { tr("Recent events", "Últimos eventos") }
    static var noEvents: String { tr("nothing yet today", "nada ainda hoje") }
    static var allCalm: String { tr("Craby — all calm", "Craby — tudo calmo") }
    static var sessionFallback: String { tr("session", "sessão") }
    static var queueSuffix: String { tr("more waiting", "na fila") }
    static var remoteOn: String { tr("Phone alerts: on (ntfy)", "Avisos no celular: ativos (ntfy)") }
    static var remoteOff: String {
        tr("Phone alerts: not set up (see README)", "Avisos no celular: não configurado (ver README)")
    }
    static var needsYouPush: String { tr("Claude needs you", "Claude precisa de você") }

    static func stateLabel(_ s: PetState) -> String {
        switch s {
        case .idle: return tr("idle", "ocioso")
        case .working: return tr("working", "trabalhando")
        case .done: return tr("done", "terminou")
        case .attention: return tr("needs you", "precisa de você")
        case .sleeping: return tr("sleeping", "dormindo")
        }
    }

    static var levelUp: String { tr("leveled up!", "subiu de nível!") }
    static func streak(_ days: Int) -> String {
        tr("🔥 \(days)-day streak", "🔥 \(days) dias seguidos")
    }
    static var about: String { tr("About Craby", "Sobre o Craby") }
    static func updateAvailable(_ v: String) -> String {
        tr("Update available: v\(v)", "Atualização disponível: v\(v)")
    }
    static var welcomeTitle: String { tr("Hi! I'm Craby 🦀", "Oi! Eu sou o Craby 🦀") }
    static var welcomeDetail: String {
        tr("I'll show you what Claude Code is up to. Click me to acknowledge alerts, drag me anywhere, right-click to quit.",
           "Vou te mostrar o que o Claude Code está fazendo. Clique em mim pra reconhecer avisos, arraste pra me mover, clique direito pra sair.")
    }
    static var welcomeOk: String { tr("Got it!", "Entendi!") }

    static func workingFor(_ minutes: Int) -> String {
        tr("working for \(minutes)min", "trabalhando há \(minutes)min")
    }

    static func todayLine(tasks: Int, projects: Int, workSeconds: Double) -> String {
        let h = Int(workSeconds) / 3600
        let m = (Int(workSeconds) % 3600) / 60
        let dur = h > 0 ? "\(h)h\(String(format: "%02d", m))" : "\(m)min"
        return tr("Today: \(tasks) tasks · \(projects) projects · \(dur)",
                  "Hoje: \(tasks) tarefas · \(projects) projetos · \(dur)")
    }

    static let levelNames: [String] = isPortuguese
        ? ["filhote", "aprendiz", "operário", "veterano", "mestre", "lenda"]
        : ["hatchling", "apprentice", "worker", "veteran", "master", "legend"]

    static func levelLine(level: Int, name: String, total: Int) -> String {
        tr("Craby — level \(level) (\(name)) · \(total) tasks all-time",
           "Craby — nível \(level) (\(name)) · \(total) tarefas no total")
    }
}
