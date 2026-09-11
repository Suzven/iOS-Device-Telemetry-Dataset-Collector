import UIKit

struct ScreenMetricProvider: MetricProvider {
    func update(_ snapshot: inout MetricSnapshot) {
        // Obtain the actual scene screen; UIScreen.main is deprecated in newer SDKs.
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let brightness = scene?.screen.brightness else { return }
        let value = Double(brightness)
        snapshot.screenBrightness = (0...1).contains(value) ? value : nil
    }
}
