import UIKit

struct BatteryMetricProvider: MetricProvider {
    func start() { UIDevice.current.isBatteryMonitoringEnabled = true }
    func update(_ snapshot: inout MetricSnapshot) {
        let device = UIDevice.current
        let level = device.batteryLevel
        snapshot.batteryLevel = (0...1).contains(level) ? level : nil
        switch device.batteryState {
        case .unknown: snapshot.batteryState = "unknown"
        case .unplugged: snapshot.batteryState = "unplugged"
        case .charging: snapshot.batteryState = "charging"
        case .full: snapshot.batteryState = "full"
        @unknown default: snapshot.batteryState = "unknown"
        }
    }
}
