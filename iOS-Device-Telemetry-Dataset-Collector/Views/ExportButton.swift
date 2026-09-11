import SwiftUI
import UIKit

private struct ExportFiles: Identifiable {
    let id = UUID()
    let urls: [URL]
}

struct ExportButton: View {
    let title: String
    let storage: DatasetStorage
    var sessionID: UUID?
    @State private var files: ExportFiles?
    @State private var errorMessage: String?
    @State private var exporting = false

    var body: some View {
        Button {
            exporting = true
            Task { @MainActor in
                await Task.yield()
                do { files = ExportFiles(urls: try DatasetExportService(storage: storage).export(sessionID: sessionID)) }
                catch { errorMessage = error.localizedDescription }
                exporting = false
            }
        } label: {
            Label(exporting ? "Preparing CSV…" : title, systemImage: "square.and.arrow.up")
        }
        .disabled(exporting)
        .sheet(item: $files) { files in ShareSheet(urls: files.urls) }
        .alert("CSV export failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let urls: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
