import Foundation
import Observation

@Observable
@MainActor
final class RequestLogger {
    private(set) var logs: [APIRequestLog] = []

    private let key = "devLog.requests"
    private let maxAge: TimeInterval = 86_400 // 24 hours

    init() { load() }

    func add(_ log: APIRequestLog) {
        pruneOld()
        logs.append(log)
        logs.sort { $0.timestamp > $1.timestamp }
        save()
    }

    func clear() {
        logs = []
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Private

    private func pruneOld() {
        let cutoff = Date().addingTimeInterval(-maxAge)
        logs = logs.filter { $0.timestamp > cutoff }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([APIRequestLog].self, from: data) else { return }
        let cutoff = Date().addingTimeInterval(-maxAge)
        logs = decoded.filter { $0.timestamp > cutoff }.sorted { $0.timestamp > $1.timestamp }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(logs) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}