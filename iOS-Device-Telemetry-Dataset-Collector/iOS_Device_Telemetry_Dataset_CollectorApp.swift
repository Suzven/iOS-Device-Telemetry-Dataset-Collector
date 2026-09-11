import SwiftUI
import SwiftData

@main
struct iOS_Device_Telemetry_Dataset_CollectorApp: App {
    var body: some Scene {
        WindowGroup { StorageBootstrapView() }
    }
}

private struct StorageBootstrapView: View {
    @State private var collector: TelemetryCollector?
    @State private var failure: String?

    var body: some View {
        Group {
            if let collector {
                ContentView(collector: collector)
                    .modelContainer(collector.storage.container)
                    .environment(\.modelContext, collector.storage.context)
            } else if let failure {
                ContentUnavailableView {
                    Label("Dataset unavailable", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your stored data has not been deleted. \(failure)")
                } actions: { Button("Retry opening storage", action: openStorage) }
            } else { ProgressView("Opening dataset…") }
        }
        .task { if collector == nil { openStorage() } }
    }

    private func openStorage() {
        do { collector = TelemetryCollector(storage: try DatasetStorage()); failure = nil }
        catch { failure = error.localizedDescription }
    }
}
