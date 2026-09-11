import UIKit
import Darwin

struct DeviceMetricProvider: MetricProvider {
    private let hardwareIdentifier: String = {
        var system = utsname()
        guard uname(&system) == 0 else { return "unknown" }
        return withUnsafeBytes(of: &system.machine) { bytes in
            String(decoding: bytes.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }()

    func update(_ snapshot: inout MetricSnapshot) {
        let info = ProcessInfo.processInfo
        snapshot.deviceModel = hardwareIdentifier
        snapshot.systemVersion = UIDevice.current.systemVersion
        snapshot.processorCount = info.processorCount
        snapshot.activeProcessorCount = info.activeProcessorCount
        snapshot.physicalMemory = Int64(clamping: info.physicalMemory)
    }
}
