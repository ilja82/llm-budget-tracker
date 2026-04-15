import Foundation
import Observation

@Observable
@MainActor
final class RequestLogger {
    private(set) var logs: [APIRequestLog] = []

    private let key = StorageKeys.DevLog.requests
    private let maxAge: TimeInterval = 86_400 // 24 hours
    private let maxEntries = 100

    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init() { load() }

    func add(_ log: APIRequestLog) {
        pruneOld()
        logs.append(log)
        logs.sort { $0.timestamp > $1.timestamp }
        scheduleSave()
    }

    func clear() {
        saveTask?.cancel()
        logs = []
        EncryptedStore.remove(forKey: key)
    }

    // MARK: - Private

    private func pruneOld() {
        let cutoff = Date().addingTimeInterval(-maxAge)
        logs = logs
            .filter { $0.timestamp > cutoff }
            .sorted { $0.timestamp > $1.timestamp }
        if logs.count > maxEntries {
            logs = Array(logs.prefix(maxEntries))
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self else { return }
            self.save()
        }
    }

    private func load() {
        let data: Data?
        do {
            data = try EncryptedStore.data(forKey: key)
        } catch EncryptedStoreError.decryptionFailed {
            EncryptedStore.remove(forKey: key)
            return
        } catch {
            return
        }
        guard let data else { return }
        guard let decoded = try? JSONDecoder().decode([APIRequestLog].self, from: data) else {
            EncryptedStore.remove(forKey: key)
            return
        }
        let cutoff = Date().addingTimeInterval(-maxAge)
        logs = Array(
            decoded
                .filter { $0.timestamp > cutoff }
                .sorted { $0.timestamp > $1.timestamp }
                .prefix(maxEntries)
        )
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(logs)
            try EncryptedStore.set(data, forKey: key)
        } catch {
            #if DEBUG
            print("[RequestLogger] Failed to encode logs: \(error)")
            #endif
        }
    }
}
