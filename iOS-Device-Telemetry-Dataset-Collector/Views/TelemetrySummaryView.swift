import SwiftUI

struct TelemetrySummaryView: View {
    let metrics: MetricSnapshot
    var body: some View {
        LabeledContent("Battery", value: metrics.batteryLevel.map { "\(Int(($0 * 100).rounded()))%" } ?? "Unavailable")
        LabeledContent("Battery state", value: metrics.batteryState.capitalized)
        LabeledContent("Brightness", value: metrics.screenBrightness.map { String(format: "%.2f", $0) } ?? "Unavailable")
        LabeledContent("Thermal", value: metrics.thermalState.capitalized)
        LabeledContent("Network", value: metrics.networkType == "wifi" ? "Wi-Fi" : metrics.networkType.capitalized)
        LabeledContent("Low Power", value: metrics.lowPowerModeEnabled ? "On" : "Off")
        LabeledContent("Motion", value: metrics.motionActivity.capitalized)
        LabeledContent("Motion access", value: metrics.motionAuthorization.replacingOccurrences(of: "_", with: " ").capitalized)
        LabeledContent("App state", value: metrics.appState.capitalized)
    }
}

func durationText(_ seconds: TimeInterval) -> String {
    let value = max(0, Int(seconds))
    return String(format: "%02d:%02d:%02d", value / 3600, (value % 3600) / 60, value % 60)
}
