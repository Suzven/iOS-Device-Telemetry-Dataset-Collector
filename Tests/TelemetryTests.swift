import XCTest
import SwiftData
@testable import iOS_Device_Telemetry_Dataset_Collector

@MainActor
final class TelemetryTests: XCTestCase {
    func testCSVHasStableSchemaAndMissingValues() {
        var metrics = MetricSnapshot()
        metrics.deviceModel = "iPhone17,1"
        metrics.lowPowerModeEnabled = true
        let date = Date(timeIntervalSince1970: 1_789_051_333.125)
        let sample = TelemetrySample(sessionID: UUID(), startedAt: date.addingTimeInterval(-60), timestamp: date, metrics: metrics)
        let csv = CSVExporter.csv(samples: [sample])
        XCTAssertTrue(csv.hasPrefix("sample_id,session_id,timestamp,timestamp_unix,session_elapsed_seconds,"))
        XCTAssertTrue(csv.contains(",1789051333.125,60.0,,unknown,,unknown,true,"))
        XCTAssertTrue(csv.contains("\"iPhone17,1\""))
        XCTAssertNil(sample.systemUptime)
        XCTAssertFalse(CSVExporter.columns.contains("optional_note"))
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        XCTAssertEqual(formatter.date(from: CSVExporter.timestamp(date)), date)
    }

    func testCSVQuotesUnicodeNewlinesAndQuotes() {
        XCTAssertEqual(CSVExporter.row(["заметка, \"тест\"\nстрока", "", "plain"]), "\"заметка, \"\"тест\"\"\nстрока\",,plain\r\n")
        XCTAssertEqual(CSVExporter.csv(samples: []), CSVExporter.row(CSVExporter.columns))
    }

    func testImmediateFinalSamplesAndBackgroundGap() throws {
        let storage = try DatasetStorage(inMemory: true)
        var clock = Date(timeIntervalSince1970: 1000)
        let collector = TelemetryCollector(storage: storage, providers: [], now: { clock })
        collector.lifecycleChanged(to: "active")
        collector.start(interval: 60)
        let session = try XCTUnwrap(collector.session)
        XCTAssertEqual(session.sampleCount, 1)
        collector.start(interval: 10)
        XCTAssertEqual(session.sampleCount, 1)
        clock = clock.addingTimeInterval(3)
        collector.lifecycleChanged(to: "inactive")
        clock = clock.addingTimeInterval(1)
        collector.lifecycleChanged(to: "background")
        clock = clock.addingTimeInterval(1800)
        collector.lifecycleChanged(to: "active")
        collector.lifecycleChanged(to: "active") // duplicate callback must do nothing
        XCTAssertEqual(session.sampleCount, 4)
        let samples = try storage.samples()
        XCTAssertEqual(samples.map(\.appState), ["active", "inactive", "background", "active"])
        XCTAssertEqual(samples.last!.timestampUnix - samples[2].timestampUnix, 1800)
        clock = clock.addingTimeInterval(2)
        collector.stop()
        XCTAssertNil(collector.session)
        XCTAssertEqual(session.sampleCount, 5)
        XCTAssertEqual(session.endedAt, clock)
        let events = try storage.context.fetch(FetchDescriptor<LifecycleEvent>(sortBy: [SortDescriptor(\.timestamp)]))
        XCTAssertEqual(events.map(\.name).sorted(), ["session_started", "app_became_inactive", "app_entered_background", "app_became_active", "sampling_resumed", "session_stopped"].sorted())
    }

    func testPersistentRecoveryAndExportIsolation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        var originalID: UUID!
        do {
            let storage = try DatasetStorage(url: url)
            let collector = TelemetryCollector(storage: storage, providers: [])
            // No active lifecycle -> no live timer in this persistence test.
            collector.start(interval: 60)
            originalID = collector.session?.id
            try storage.transaction { collector.session?.optionalNote = "улица, \"день\"\nвторая строка" }
        }
        let reopened = try DatasetStorage(url: url)
        let collector = TelemetryCollector(storage: reopened, providers: [])
        XCTAssertEqual(collector.session?.id, originalID)
        XCTAssertEqual(collector.session?.sampleCount, 1)
        collector.lifecycleChanged(to: "active")
        XCTAssertEqual(collector.session?.sampleCount, 2)
        collector.stop()
        collector.start(interval: 30)
        collector.stop()
        let urls = try DatasetExportService(storage: reopened).export(sessionID: originalID)
        defer { try? FileManager.default.removeItem(at: urls[0].deletingLastPathComponent()) }
        XCTAssertEqual(urls.count, 3)
        let samples = try String(contentsOf: urls[0], encoding: .utf8)
        XCTAssertEqual(samples.components(separatedBy: "\r\n").count - 2, 3)
        XCTAssertFalse(samples.contains("улица"))
        let sessions = try String(contentsOf: urls[1], encoding: .utf8)
        XCTAssertTrue(sessions.contains("\"улица, \"\"день\"\"\nвторая строка\""))
        XCTAssertEqual(try reopened.countSamples(), 5)
    }

    func testPeriodicSamplingUsesRealTimesAndStops() async throws {
        let storage = try DatasetStorage(inMemory: true)
        let collector = TelemetryCollector(storage: storage, providers: [])
        collector.lifecycleChanged(to: "active")
        collector.start(interval: 10)
        defer { collector.stop() }
        try await Task.sleep(for: .seconds(10.5))
        let samples = try storage.samples()
        XCTAssertEqual(samples.count, 2)
        XCTAssertGreaterThanOrEqual(samples[1].timestamp.timeIntervalSince(samples[0].timestamp), 10)
        collector.stop()
        let count = try storage.countSamples()
        collector.stop()
        XCTAssertEqual(try storage.countSamples(), count)
    }

    func testTransactionRollbackDoesNotLeavePartialSession() throws {
        enum Failure: Error { case simulated }
        let storage = try DatasetStorage(inMemory: true)
        XCTAssertThrowsError(try storage.transaction {
            storage.context.insert(CollectionSession())
            throw Failure.simulated
        })
        XCTAssertNil(try storage.activeSession())
        XCTAssertEqual(try storage.countSamples(), 0)
    }
}
