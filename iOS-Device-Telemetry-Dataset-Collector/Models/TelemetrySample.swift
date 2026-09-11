import Foundation
import SwiftData

/// One observation. No inferred usage labels or derived battery features.
@Model
final class TelemetrySample {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var timestamp: Date
    var timestampUnix: Double
    var sessionElapsedSeconds: Double
    var batteryLevel: Float?
    var batteryState: String
    var screenBrightness: Double?
    var thermalState: String
    var lowPowerModeEnabled: Bool
    var networkType: String
    var networkExpensive: Bool?
    var networkConstrained: Bool?
    var motionActivity: String
    var motionAuthorization: String
    var motionActivityTimestamp: Date?
    var motionStationary: Bool?
    var motionWalking: Bool?
    var motionRunning: Bool?
    var motionCycling: Bool?
    var motionAutomotive: Bool?
    var motionConfidence: String?
    var appState: String
    var deviceModel: String
    var systemVersion: String
    var processorCount: Int
    var activeProcessorCount: Int
    var physicalMemory: Int64
    // Reserved column: Apple's approved reasons do not cover raw uptime dataset export.
    var systemUptime: Double?

    init(sessionID: UUID, startedAt: Date, timestamp: Date, metrics: MetricSnapshot) {
        id = UUID()
        self.sessionID = sessionID
        self.timestamp = timestamp
        timestampUnix = timestamp.timeIntervalSince1970
        sessionElapsedSeconds = timestamp.timeIntervalSince(startedAt)
        batteryLevel = metrics.batteryLevel
        batteryState = metrics.batteryState
        screenBrightness = metrics.screenBrightness
        thermalState = metrics.thermalState
        lowPowerModeEnabled = metrics.lowPowerModeEnabled
        networkType = metrics.networkType
        networkExpensive = metrics.networkExpensive
        networkConstrained = metrics.networkConstrained
        motionActivity = metrics.motionActivity
        motionAuthorization = metrics.motionAuthorization
        motionActivityTimestamp = metrics.motionActivityTimestamp
        motionStationary = metrics.motionStationary
        motionWalking = metrics.motionWalking
        motionRunning = metrics.motionRunning
        motionCycling = metrics.motionCycling
        motionAutomotive = metrics.motionAutomotive
        motionConfidence = metrics.motionConfidence
        appState = metrics.appState
        deviceModel = metrics.deviceModel
        systemVersion = metrics.systemVersion
        processorCount = metrics.processorCount
        activeProcessorCount = metrics.activeProcessorCount
        physicalMemory = metrics.physicalMemory
        systemUptime = nil
    }
}
