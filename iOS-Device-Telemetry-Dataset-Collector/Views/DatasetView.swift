import SwiftUI
import SwiftData

struct DatasetView: View {
    let storage: DatasetStorage
    @Query(sort: \CollectionSession.startedAt, order: .reverse) private var sessions: [CollectionSession]
    @State private var size = "—"

    var body: some View {
        List {
            Section("Dataset") {
                LabeledContent("Sessions", value: String(sessions.count))
                LabeledContent("Samples", value: String(sessions.reduce(0) { $0 + $1.sampleCount }))
                LabeledContent("Storage size", value: size)
                ExportButton(title: "Export all CSV", storage: storage)
            }
            Section("Sessions") {
                if sessions.isEmpty { Text("Start a collection to create your first session.").foregroundStyle(.secondary) }
                ForEach(sessions) { session in
                    NavigationLink {
                        SessionDetailView(session: session, storage: storage)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.headline)
                            Text("\(durationText((session.endedAt ?? Date()).timeIntervalSince(session.startedAt))) · \(session.sampleCount) samples\(session.endedAt == nil ? " · Open" : "")")
                                .font(.subheadline).foregroundStyle(.secondary)
                            if let note = session.optionalNote, !note.isEmpty { Text(note).font(.caption).lineLimit(2) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Dataset")
        .task(id: sessions.reduce(0) { $0 + $1.sampleCount }) {
            do { size = ByteCountFormatter.string(fromByteCount: try storage.storageBytes(), countStyle: .file) }
            catch { size = "Unavailable" }
        }
    }
}
