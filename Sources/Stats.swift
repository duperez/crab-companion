import Foundation

// ---------------------------------------------------------------------------
// Estatísticas e memória do dia: quantas tarefas o Claude concluiu, em quais
// projetos, quanto tempo trabalhando — mais um registro dos últimos eventos.
// Persistido em ~/Library/Application Support/Craby/stats.json.
// ---------------------------------------------------------------------------

struct CrabyEvent: Codable {
    let ts: Date
    let project: String
    let kind: String // "done" | "attention"
}

struct DayStats: Codable {
    var tasks = 0
    var projects: [String] = []
    var workSeconds: Double = 0
    var maxBrood: Int? // opcional p/ compatibilidade com stats antigos
}

struct StatsData: Codable {
    var totalTasks = 0
    var days: [String: DayStats] = [:]
    var events: [CrabyEvent] = []
}

final class StatsStore {
    private let url: URL
    private(set) var data = StatsData()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(url: URL) {
        self.url = url
        if let raw = try? Data(contentsOf: url),
           let loaded = try? JSONDecoder().decode(StatsData.self, from: raw) {
            data = loaded
        }
    }

    private func dayKey(_ date: Date = Date()) -> String {
        Self.dayFormatter.string(from: date)
    }

    var today: DayStats { data.days[dayKey()] ?? DayStats() }

    func recordDone(project: String) {
        var day = today
        day.tasks += 1
        if !day.projects.contains(project) { day.projects.append(project) }
        data.days[dayKey()] = day
        data.totalTasks += 1
        appendEvent(project: project, kind: "done")
    }

    func recordAttention(project: String) {
        appendEvent(project: project, kind: "attention")
    }

    // registra o tamanho atual da ninhada; retorna true se é um novo recorde (>1)
    func recordBrood(count: Int) -> Bool {
        var day = today
        let previous = day.maxBrood ?? 0
        guard count > previous else { return false }
        day.maxBrood = count
        data.days[dayKey()] = day
        save()
        return count > 1
    }

    func addWork(project: String, seconds: Double) {
        guard seconds > 0, seconds < 12 * 3600 else { return } // descarta absurdos
        var day = today
        day.workSeconds += seconds
        if !day.projects.contains(project) { day.projects.append(project) }
        data.days[dayKey()] = day
        save()
    }

    func recentEvents(limit: Int = 10) -> [CrabyEvent] {
        Array(data.events.suffix(limit).reversed())
    }

    private func appendEvent(project: String, kind: String) {
        data.events.append(CrabyEvent(ts: Date(), project: project, kind: kind))
        if data.events.count > 50 { data.events.removeFirst(data.events.count - 50) }
        save()
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let raw = try? encoder.encode(data) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? raw.write(to: url, options: .atomic)
    }
}
