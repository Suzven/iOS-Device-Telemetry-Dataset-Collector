import Foundation
import CoreMotion

final class MotionMetricProvider: MetricProvider {
    private lazy var manager = CMMotionActivityManager()
    private var activity: CMMotionActivity?
    private var running = false
    private var requested = false
    private var generation = UUID()

    func start() {
        requested = true
        guard !running, CMMotionActivityManager.isActivityAvailable() else { return }
        let status = CMMotionActivityManager.authorizationStatus()
        guard status != .denied, status != .restricted else { return }
        running = true
        generation = UUID()
        let token = generation
        manager.startActivityUpdates(to: .main) { [weak self] activity in
            MainActor.assumeIsolated {
                guard let self, self.generation == token else { return }
                self.activity = activity
            }
        }
    }

    func stop() {
        guard running else { return }
        generation = UUID()
        manager.stopActivityUpdates()
        activity = nil
        running = false
    }

    func update(_ snapshot: inout MetricSnapshot) {
        // Do not touch Core Motion at all before an explicit collection start/resume.
        guard requested else { return }
        guard CMMotionActivityManager.isActivityAvailable() else {
            snapshot.motionAuthorization = "unavailable"
            return
        }
        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized: snapshot.motionAuthorization = "authorized"
        case .denied: snapshot.motionAuthorization = "denied"
        case .restricted: snapshot.motionAuthorization = "restricted"
        case .notDetermined: snapshot.motionAuthorization = "not_determined"
        @unknown default: snapshot.motionAuthorization = "unknown"
        }
        guard snapshot.motionAuthorization == "authorized", let activity else { return }
        snapshot.motionActivityTimestamp = activity.startDate
        snapshot.motionStationary = activity.stationary
        snapshot.motionWalking = activity.walking
        snapshot.motionRunning = activity.running
        snapshot.motionCycling = activity.cycling
        snapshot.motionAutomotive = activity.automotive
        switch activity.confidence {
        case .low: snapshot.motionConfidence = "low"
        case .medium: snapshot.motionConfidence = "medium"
        case .high: snapshot.motionConfidence = "high"
        @unknown default: snapshot.motionConfidence = "unknown"
        }
        // Core Motion flags are not mutually exclusive. Preserve flags; don't invent a priority.
        let flags = [(activity.stationary, "stationary"), (activity.walking, "walking"),
                     (activity.running, "running"), (activity.cycling, "cycling"),
                     (activity.automotive, "automotive")].filter { $0.0 }
        snapshot.motionActivity = !activity.unknown && flags.count == 1 ? flags[0].1 : "unknown"
    }
}
