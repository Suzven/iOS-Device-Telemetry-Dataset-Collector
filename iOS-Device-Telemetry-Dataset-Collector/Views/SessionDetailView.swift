import SwiftUI

struct SessionDetailView: View {
    let session: CollectionSession
    let storage: DatasetStorage
    @State private var note = ""
    @State private var recent: [TelemetrySample] = []
    @State private var batteryRange = "—"
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Session") {
                LabeledContent("Started", value: session.startedAt.formatted(date: .abbreviated, time: .standard))
                LabeledContent("Ended", value: session.endedAt?.formatted(date: .abbreviated, time: .standard) ?? "Open")
                LabeledContent("Duration", value: durationText((session.endedAt ?? Date()).timeIntervalSince(session.startedAt)))
                LabeledContent("Samples", value: String(session.sampleCount))
                LabeledContent("Battery", value: batteryRange)
                LabeledContent("Interval", value: "\(Int(session.samplingInterval)) sec")
            }
            Section {
                TextField("Optional note", text: $note, axis: .vertical).lineLimit(3...8)
                Button("Save note") {
                    do { try storage.transaction { session.optionalNote = note.isEmpty ? nil : note } }
                    catch { errorMessage = error.localizedDescription }
                }.disabled(note == (session.optionalNote ?? ""))
            } header: { Text("Note") } footer: { Text("Human metadata only. Notes are exported in the separate sessions CSV.") }
            Section { ExportButton(title: "Export session CSV", storage: storage, sessionID: session.id) }
            Section("Latest observations") {
                ForEach(recent) { sample in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(sample.timestamp.formatted(date: .omitted, time: .standard)).monospacedDigit()
                        Text("\(sample.batteryLevel.map { "\(Int(($0 * 100).rounded()))%" } ?? "Unknown battery") · \(sample.networkType) · \(sample.appState)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Session")
        .onAppear { note = session.optionalNote ?? "" }
        .task(id: session.sampleCount) {
            do {
                recent = try storage.samples(sessionID: session.id, limit: 10, newestFirst: true)
                let first = try storage.samples(sessionID: session.id, limit: 1).first?.batteryLevel
                let last = recent.first?.batteryLevel
                let format: (Float?) -> String = { $0.map { "\(Int(($0 * 100).rounded()))%" } ?? "Unknown" }
                batteryRange = "\(format(first)) → \(format(last))"
            } catch { errorMessage = error.localizedDescription }
        }
        .alert("Storage error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}
