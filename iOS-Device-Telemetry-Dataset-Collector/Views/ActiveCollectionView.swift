import SwiftUI

struct ActiveCollectionView: View {
    @Bindable var collector: TelemetryCollector
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if let session = collector.session {
                Section {
                    Label(collector.samplingPaused ? "Paused — storage error" : "Recording", systemImage: collector.samplingPaused ? "pause.circle" : "record.circle")
                        .font(.headline).foregroundStyle(collector.samplingPaused ? .orange : .red)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        LabeledContent("Duration", value: durationText(context.date.timeIntervalSince(session.startedAt)))
                            .monospacedDigit()
                    }
                    LabeledContent("Samples", value: String(session.sampleCount))
                    LabeledContent("Sampling", value: "Every \(Int(session.samplingInterval)) sec")
                }
                Section("Current telemetry") { TelemetrySummaryView(metrics: collector.current) }
                if collector.samplingPaused {
                    Button("Retry sampling") { collector.retrySampling() }
                }
                Section {
                    Button("Stop collection", role: .destructive) {
                        collector.stop()
                        if collector.session == nil { dismiss() }
                    }
                } footer: { Text("A final observation is saved when you stop. No samples are invented for time spent suspended.") }
            } else {
                Text("Collection finished")
            }
        }
        .navigationTitle("Active Collection")
        .task {
            while !Task.isCancelled {
                collector.refresh()
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }
}
