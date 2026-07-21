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

    // nível do Craby: cresce com o total de tarefas concluídas
    var level: (number: Int, name: String) {
        let thresholds = [0, 10, 50, 150, 400, 1000]
        let idx = thresholds.lastIndex(where: { data.totalTasks >= $0 }) ?? 0
        let names = L.levelNames
        return (idx + 1, names[min(idx, names.count - 1)])
    }

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

    func recordLevelUp() {
        appendEvent(project: "Craby", kind: "level")
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

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let raw = try? encoder.encode(data) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? raw.write(to: url, options: .atomic)
    }
}
