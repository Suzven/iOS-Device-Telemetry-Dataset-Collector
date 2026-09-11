import Foundation
import Network

final class NetworkMetricProvider: MetricProvider {
    private var monitor: NWPathMonitor?
    private var type = "unknown"
    private var expensive: Bool?
    private var constrained: Bool?
    private var generation = UUID()

    func start() {
        guard monitor == nil else { return }
        generation = UUID()
        let token = generation
        let monitor = NWPathMonitor()
        self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let type: String
            if path.status != .satisfied { type = "none" }
            else if path.usesInterfaceType(.wifi) { type = "wifi" }
            else if path.usesInterfaceType(.cellular) { type = "cellular" }
            else if path.usesInterfaceType(.wiredEthernet) { type = "wired" }
            else { type = "other" }
            let expensive = path.isExpensive
            let constrained = path.isConstrained
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.type = type
                self.expensive = expensive
                self.constrained = constrained
            }
        }
        monitor.start(queue: DispatchQueue(label: "telemetry.network"))
    }

    func stop() {
        generation = UUID()
        monitor?.cancel()
        monitor = nil
        type = "unknown"
        expensive = nil
        constrained = nil
    }

    func update(_ snapshot: inout MetricSnapshot) {
        snapshot.networkType = type
        snapshot.networkExpensive = expensive
        snapshot.networkConstrained = constrained
    }
}
