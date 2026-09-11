import Foundation

struct MetricSnapshot {
    var batteryLevel: Float?
    var batteryState = "unknown"
    var screenBrightness: Double?
    var thermalState = "unknown"
    var lowPowerModeEnabled = false
    var networkType = "unknown"
    var networkExpensive: Bool?
    var networkConstrained: Bool?
    var motionActivity = "unknown"
    var motionAuthorization = "not_determined"
    var motionActivityTimestamp: Date?
    var motionStationary: Bool?
    var motionWalking: Bool?
    var motionRunning: Bool?
    var motionCycling: Bool?
    var motionAutomotive: Bool?
    var motionConfidence: String?
    var appState = "unknown"
    var deviceModel = "unknown"
    var systemVersion = "unknown"
    var processorCount = 0
    var activeProcessorCount = 0
    var physicalMemory: Int64 = 0
}

@MainActor
protocol MetricProvider {
    func update(_ snapshot: inout MetricSnapshot)
    func start()
    func stop()
}

extension MetricProvider {
    func start() {}
    func stop() {}
}
