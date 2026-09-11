import UIKit

struct LifecycleMetricProvider: MetricProvider {
    func update(_ snapshot: inout MetricSnapshot) {
        switch UIApplication.shared.applicationState {
        case .active: snapshot.appState = "active"
        case .inactive: snapshot.appState = "inactive"
        case .background: snapshot.appState = "background"
        @unknown default: snapshot.appState = "unknown"
        }
    }
}
