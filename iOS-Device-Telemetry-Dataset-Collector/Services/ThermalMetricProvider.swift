import Foundation

struct ThermalMetricProvider: MetricProvider {
    func update(_ snapshot: inout MetricSnapshot) {
        let info = ProcessInfo.processInfo
        snapshot.lowPowerModeEnabled = info.isLowPowerModeEnabled
        switch info.thermalState {
        case .nominal: snapshot.thermalState = "nominal"
        case .fair: snapshot.thermalState = "fair"
        case .serious: snapshot.thermalState = "serious"
        case .critical: snapshot.thermalState = "critical"
        @unknown default: snapshot.thermalState = "unknown"
        }
    }
}
