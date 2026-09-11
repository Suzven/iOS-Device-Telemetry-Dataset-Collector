import Foundation
import SwiftData

@MainActor
final class DatasetStorage {
    let container: ModelContainer
    let context: ModelContext
    let storeURL: URL

    init(inMemory: Bool = false, url: URL? = nil) throws {
        let schema = Schema([CollectionSession.self, TelemetrySample.self, LifecycleEvent.self])
        let directory = URL.applicationSupportDirectory.appendingPathComponent("Telemetry", isDirectory: true)
        if !inMemory { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        storeURL = url ?? directory.appendingPathComponent("dataset.store")
        let configuration = inMemory
            ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            : ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .none)
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    /// Samples, counts and events commit together, or all changes roll back.
    func transaction(_ operation: () throws -> Void) throws {
        do {
            try operation()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func activeSession() throws -> CollectionSession? {
        var query = FetchDescriptor<CollectionSession>(
            predicate: #Predicate { $0.endedAt == nil }, sortBy: [SortDescriptor(\.startedAt)])
        query.fetchLimit = 1
        return try context.fetch(query).first
    }

    func samples(sessionID: UUID? = nil, offset: Int = 0, limit: Int = 500, newestFirst: Bool = false) throws -> [TelemetrySample] {
        var query = FetchDescriptor<TelemetrySample>(sortBy: [
            SortDescriptor(\.timestamp, order: newestFirst ? .reverse : .forward), SortDescriptor(\.id)
        ])
        if let sessionID { query.predicate = #Predicate { $0.sessionID == sessionID } }
        query.fetchOffset = offset
        query.fetchLimit = limit
        return try context.fetch(query)
    }

    func countSamples() throws -> Int { try context.fetchCount(FetchDescriptor<TelemetrySample>()) }

    func storageBytes() throws -> Int64 {
        try [storeURL, URL(fileURLWithPath: storeURL.path + "-wal"), URL(fileURLWithPath: storeURL.path + "-shm")]
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .reduce(0) { total, url in
                let values = try url.resourceValues(forKeys: [.fileSizeKey])
                return total + Int64(values.fileSize ?? 0)
            }
    }
}
