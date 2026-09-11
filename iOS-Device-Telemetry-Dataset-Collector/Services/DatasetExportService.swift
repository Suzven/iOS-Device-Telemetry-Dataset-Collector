import Foundation
import SwiftData

@MainActor
final class DatasetExportService {
    private let storage: DatasetStorage
    init(storage: DatasetStorage) { self.storage = storage }

    /// Fetch and write in bounded batches so a multi-day dataset need not fit in RAM.
    /// One main-actor operation provides a consistent export while sampling is serialized.
    func export(sessionID: UUID? = nil) throws -> [URL] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TelemetryExports/\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd_HH-mm"
            let base = sessionID.map { "device_telemetry_session_\($0.uuidString)" }
                ?? "device_telemetry_\(formatter.string(from: Date()))"
            let samplesURL = directory.appendingPathComponent(base + ".csv")
            try writeFile(samplesURL) { handle in
                try append(CSVExporter.row(CSVExporter.columns), to: handle)
                var offset = 0
                while true {
                    let batch = try storage.samples(sessionID: sessionID, offset: offset)
                    if batch.isEmpty { break }
                    for sample in batch { try append(CSVExporter.sampleRow(sample), to: handle) }
                    offset += batch.count
                }
            }
            let sessionsURL = directory.appendingPathComponent(base + "_sessions.csv")
            try writeFile(sessionsURL) { handle in
                try append(CSVExporter.row(["session_id", "started_at", "ended_at", "sample_count", "sampling_interval_seconds", "optional_note"]), to: handle)
                var query = FetchDescriptor<CollectionSession>(sortBy: [SortDescriptor(\.startedAt)])
                if let sessionID { query.predicate = #Predicate { $0.id == sessionID } }
                for session in try storage.context.fetch(query) {
                    try append(CSVExporter.row([session.id.uuidString, CSVExporter.timestamp(session.startedAt),
                        session.endedAt.map { CSVExporter.timestamp($0) } ?? "", String(session.sampleCount),
                        String(session.samplingInterval), session.optionalNote ?? ""]), to: handle)
                }
            }
            let eventsURL = directory.appendingPathComponent(base + "_events.csv")
            try writeFile(eventsURL) { handle in
                try append(CSVExporter.row(["event_id", "session_id", "timestamp", "timestamp_unix", "event", "app_state"]), to: handle)
                var query = FetchDescriptor<LifecycleEvent>(sortBy: [SortDescriptor(\.timestamp)])
                if let sessionID { query.predicate = #Predicate { $0.sessionID == sessionID } }
                query.fetchLimit = 500
                while true {
                    let batch = try storage.context.fetch(query)
                    if batch.isEmpty { break }
                    for event in batch {
                        try append(CSVExporter.row([event.id.uuidString, event.sessionID.uuidString,
                            CSVExporter.timestamp(event.timestamp), String(event.timestamp.timeIntervalSince1970),
                            event.name, event.appState]), to: handle)
                    }
                    query.fetchOffset = (query.fetchOffset ?? 0) + batch.count
                }
            }
            return [samplesURL, sessionsURL, eventsURL]
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    private func writeFile(_ url: URL, body: (FileHandle) throws -> Void) throws {
        try Data().write(to: url)
        let handle = try FileHandle(forWritingTo: url)
        do { try body(handle); try handle.close() }
        catch { try? handle.close(); throw error }
    }

    private func append(_ text: String, to handle: FileHandle) throws {
        try handle.write(contentsOf: Data(text.utf8))
    }
}
