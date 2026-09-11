import Foundation

/// Formatting only: no sensor or storage access. Empty fields represent missing observations.
enum CSVExporter {
    static let columns = [
        "sample_id", "session_id", "timestamp", "timestamp_unix", "session_elapsed_seconds",
        "battery_level", "battery_state", "screen_brightness", "thermal_state", "low_power_mode",
        "network_type", "motion_activity", "app_state", "device_model", "system_version",
        "processor_count", "active_processor_count", "physical_memory", "system_uptime",
        "network_expensive", "network_constrained", "motion_authorization", "motion_activity_timestamp",
        "motion_stationary", "motion_walking", "motion_running", "motion_cycling", "motion_automotive", "motion_confidence"
    ]

    static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func row(_ fields: [String]) -> String { fields.map { escape($0) }.joined(separator: ",") + "\r\n" }

    static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private static func value<T>(_ value: T?) -> String { value.map { String(describing: $0) } ?? "" }

    static func sampleRow(_ sample: TelemetrySample) -> String {
        row([
            sample.id.uuidString, sample.sessionID.uuidString, timestamp(sample.timestamp),
            String(sample.timestampUnix), String(sample.sessionElapsedSeconds), value(sample.batteryLevel),
            sample.batteryState, value(sample.screenBrightness), sample.thermalState, String(sample.lowPowerModeEnabled),
            sample.networkType, sample.motionActivity, sample.appState, sample.deviceModel, sample.systemVersion,
            String(sample.processorCount), String(sample.activeProcessorCount), String(sample.physicalMemory), value(sample.systemUptime),
            value(sample.networkExpensive), value(sample.networkConstrained), sample.motionAuthorization,
            sample.motionActivityTimestamp.map { timestamp($0) } ?? "", value(sample.motionStationary), value(sample.motionWalking),
            value(sample.motionRunning), value(sample.motionCycling), value(sample.motionAutomotive), value(sample.motionConfidence)
        ])
    }

    static func csv(samples: [TelemetrySample]) -> String { row(columns) + samples.map { sampleRow($0) }.joined() }
}
