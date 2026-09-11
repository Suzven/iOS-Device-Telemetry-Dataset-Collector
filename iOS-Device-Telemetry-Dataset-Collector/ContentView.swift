import SwiftUI

struct ContentView: View {
    @Bindable var collector: TelemetryCollector
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack { DashboardView(collector: collector) }
            .tint(.teal)
            .onChange(of: scenePhase, initial: true) { _, phase in
                switch phase {
                case .active: collector.lifecycleChanged(to: "active")
                case .inactive: collector.lifecycleChanged(to: "inactive")
                case .background: collector.lifecycleChanged(to: "background")
                @unknown default: collector.lifecycleChanged(to: "unknown")
                }
            }
            .alert("Collection needs attention", isPresented: Binding(
                get: { collector.errorMessage != nil }, set: { if !$0 { collector.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { collector.errorMessage = nil }
            } message: { Text(collector.errorMessage ?? "") }
    }
}
