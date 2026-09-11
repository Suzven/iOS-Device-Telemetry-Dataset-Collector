import SwiftUI
import SwiftData

struct DashboardView: View {
    @Bindable var collector: TelemetryCollector
    @Query(sort: \CollectionSession.startedAt, order: .reverse) private var sessions: [CollectionSession]
    @AppStorage("samplingInterval") private var interval = 60
    @State private var showingCollection = false

    var body: some View {
        List {
            Section {
                Label("Raw device telemetry", systemImage: "waveform.path.ecg")
                    .font(.headline).foregroundStyle(.teal)
                Text("Record observable device metrics and export a dataset for your own analysis.")
                    .foregroundStyle(.secondary)
            }
            if collector.session != nil {
                Section { NavigationLink("Open active collection") { ActiveCollectionView(collector: collector) } }
            }
            Section {
                Picker("Sampling interval", selection: $interval) {
                    ForEach([10, 30, 60, 120], id: \.self) { Text("\($0) sec").tag($0) }
                }.disabled(collector.session != nil)
                if collector.session == nil {
                    Button {
                        collector.start(interval: Double(interval))
                        showingCollection = collector.session != nil
                    } label: {
                        Label("Start collection", systemImage: "record.circle").font(.headline)
                    }
                }
            } header: { Text("Collection") } footer: {
                Text("iOS suspends ordinary apps in the background. Recording resumes when you return; gaps are preserved. Motion access is optional.")
            }
            Section("Current telemetry") { TelemetrySummaryView(metrics: collector.current) }
            Section("Dataset") {
                LabeledContent("Sessions", value: String(sessions.count))
                LabeledContent("Samples", value: String(sessions.reduce(0) { $0 + $1.sampleCount }))
                NavigationLink("View dataset") { DatasetView(storage: collector.storage) }
                ExportButton(title: "Export all CSV", storage: collector.storage)
            }
            Section("Device") {
                LabeledContent("Hardware", value: collector.current.deviceModel)
                LabeledContent("iOS", value: collector.current.systemVersion)
            }
        }
        .navigationTitle("Telemetry Collector")
        .navigationDestination(isPresented: $showingCollection) { ActiveCollectionView(collector: collector) }
        .task {
            while !Task.isCancelled {
                collector.refresh()
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }
}
