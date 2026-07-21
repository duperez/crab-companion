import Foundation

// Idioma: pt/es se o sistema estiver neles; inglês caso contrário.
enum CrabyLang { case en, pt, es }

let lang: CrabyLang = {
    let first = Locale.preferredLanguages.first?.lowercased() ?? "en"
    if first.hasPrefix("pt") { return .pt }
    if first.hasPrefix("es") { return .es }
    return .en
}()

// es vazio cai no inglês
func tr(_ en: String, _ pt: String, _ es: String = "") -> String {
    switch lang {
    case .en: return en
    case .pt: return pt
    case .es: return es.isEmpty ? en : es
    }
}

enum L {
    static var allow: String { tr("Allow", "Permitir", "Permitir") }
    static var deny: String { tr("Deny", "Negar", "Denegar") }
    static var terminal: String { tr("Terminal", "Terminal", "Terminal") }
    static var answerInTerminal: String {
        tr("Answer in the terminal", "Responder no terminal", "Responder en la terminal")
    }
    static var send: String { tr("Send", "Enviar", "Enviar") }
    static var typeAnswer: String {
        tr("Type your answer…", "Digite sua resposta…", "Escribe tu respuesta…")
    }
    static var collapseToBar: String {
        tr("Collapse to menu bar", "Recolher para a barra", "Plegar a la barra")
    }
    static var showFloating: String {
        tr("Show floating Craby", "Mostrar flutuante", "Mostrar flotante")
    }
    static var sounds: String { tr("Sounds", "Sons", "Sonidos") }
    static var quit: String { tr("Quit", "Sair", "Salir") }
    static var resetPosition: String {
        tr("Reset position", "Redefinir posição", "Restablecer posición")
    }
    static var recentEvents: String {
        tr("Recent events", "Últimos eventos", "Eventos recientes")
    }
    static var noEvents: String {
        tr("nothing yet today", "nada ainda hoje", "nada todavía hoy")
    }
    static var allCalm: String {
        tr("Craby — all calm", "Craby — tudo calmo", "Craby — todo tranquilo")
    }
    static var sessionFallback: String { tr("session", "sessão", "sesión") }
    static var queueSuffix: String { tr("more waiting", "na fila", "en cola") }
    static var remoteOn: String {
        tr("Phone alerts: on (ntfy)", "Avisos no celular: ativos (ntfy)",
           "Avisos al móvil: activos (ntfy)")
    }
    static var remoteOff: String {
        tr("Phone alerts: not set up (see README)",
           "Avisos no celular: não configurado (ver README)",
           "Avisos al móvil: sin configurar (ver README)")
    }
    static var needsYouPush: String {
        tr("Claude needs you", "Claude precisa de você", "Claude te necesita")
    }

    static func stateLabel(_ s: PetState) -> String {
        switch s {
        case .idle: return tr("idle", "ocioso", "inactivo")
        case .working: return tr("working", "trabalhando", "trabajando")
        case .done: return tr("done", "terminou", "terminó")
        case .attention: return tr("needs you", "precisa de você", "te necesita")
        case .sleeping: return tr("sleeping", "dormindo", "durmiendo")
        }
    }

    static var levelUp: String { tr("leveled up!", "subiu de nível!", "¡subió de nivel!") }
    static func streak(_ days: Int) -> String {
        tr("🔥 \(days)-day streak", "🔥 \(days) dias seguidos", "🔥 \(days) días seguidos")
    }
    static var about: String { tr("About Craby", "Sobre o Craby", "Acerca de Craby") }
    static func updateAvailable(_ v: String) -> String {
        tr("Update available: v\(v)", "Atualização disponível: v\(v)",
           "Actualización disponible: v\(v)")
    }
    static func updateNow(_ v: String) -> String {
        tr("Update to v\(v) now", "Atualizar agora para v\(v)", "Actualizar ahora a v\(v)")
    }
    static var updating: String {
        tr("Downloading update… 🦀", "Baixando atualização… 🦀", "Descargando actualización… 🦀")
    }
    static var updateFailed: String {
        tr("Update failed — grab it on the releases page",
           "Falha na atualização — baixe na página de releases",
           "Error al actualizar — descárgala en la página de releases")
    }
    static var welcomeTitle: String {
        tr("Hi! I'm Craby 🦀", "Oi! Eu sou o Craby 🦀", "¡Hola! Soy Craby 🦀")
    }
    static var welcomeDetail: String {
        tr("I'll show you what Claude Code is up to. Click me to acknowledge alerts, drag me anywhere, right-click to quit.",
           "Vou te mostrar o que o Claude Code está fazendo. Clique em mim pra reconhecer avisos, arraste pra me mover, clique direito pra sair.",
           "Te mostraré lo que hace Claude Code. Haz clic para reconocer avisos, arrástrame a donde quieras, clic derecho para salir.")
    }
    static var welcomeOk: String { tr("Got it!", "Entendi!", "¡Entendido!") }

    static func workingFor(_ minutes: Int) -> String {
        tr("working for \(minutes)min", "trabalhando há \(minutes)min",
           "trabajando hace \(minutes)min")
    }

    static func todayLine(tasks: Int, projects: Int, workSeconds: Double) -> String {
        let h = Int(workSeconds) / 3600
        let m = (Int(workSeconds) % 3600) / 60
        let dur = h > 0 ? "\(h)h\(String(format: "%02d", m))" : "\(m)min"
        return tr("Today: \(tasks) tasks · \(projects) projects · \(dur)",
                  "Hoje: \(tasks) tarefas · \(projects) projetos · \(dur)",
                  "Hoy: \(tasks) tareas · \(projects) proyectos · \(dur)")
    }

    static let levelNames: [String] = {
        switch lang {
        case .en: return ["hatchling", "apprentice", "worker", "veteran", "master", "legend"]
        case .pt: return ["filhote", "aprendiz", "operário", "veterano", "mestre", "lenda"]
        case .es: return ["cría", "aprendiz", "obrero", "veterano", "maestro", "leyenda"]
        }
    }()

    static func levelLine(level: Int, name: String, total: Int) -> String {
        tr("Craby — level \(level) (\(name)) · \(total) tasks all-time",
           "Craby — nível \(level) (\(name)) · \(total) tarefas no total",
           "Craby — nivel \(level) (\(name)) · \(total) tareas en total")
    }

    // Preferências
    static var preferences: String { tr("Preferences…", "Preferências…", "Preferencias…") }
    static var prefsTitle: String {
        tr("Craby — Preferences", "Craby — Preferências", "Craby — Preferencias")
    }
    static var prefsNtfy: String {
        tr("ntfy topic (phone alerts):", "Tópico ntfy (avisos no celular):",
           "Tema ntfy (avisos al móvil):")
    }
    static var prefsSoundTheme: String {
        tr("Sound theme:", "Tema de sons:", "Tema de sonidos:")
    }
    static func themeName(_ key: String) -> String {
        switch key {
        case "soft": return tr("Soft", "Suave", "Suave")
        case "retro": return tr("Retro", "Retrô", "Retro")
        default: return tr("Classic", "Clássico", "Clásico")
        }
    }
    static var prefsHideOnShare: String {
        tr("Hide while screen is shared", "Recolher ao compartilhar a tela",
           "Ocultar al compartir pantalla")
    }
    static var prefsOpenFolder: String {
        tr("Open config folder", "Abrir pasta de configuração", "Abrir carpeta de configuración")
    }

    // Frases do Craby (toasts)
    static var goodMorning: String { tr("Good morning! ☀️", "Bom dia! ☀️", "¡Buenos días! ☀️") }
    static func tasksMilestone(_ n: Int) -> String {
        tr("\(n) tasks today! 💪", "\(n) tarefas hoje! 💪", "¡\(n) tareas hoy! 💪")
    }
    static func broodRecord(_ n: Int) -> String {
        tr("Biggest brood today: \(n) 🐣", "Maior ninhada do dia: \(n) 🐣",
           "Mayor camada de hoy: \(n) 🐣")
    }
    static func broodLine(_ n: Int) -> String {
        tr("🐣 biggest brood today: \(n)", "🐣 maior ninhada do dia: \(n)",
           "🐣 mayor camada de hoy: \(n)")
    }
}
