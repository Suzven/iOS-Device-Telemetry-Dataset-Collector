import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TelemetryCollector {
    private(set) var session: CollectionSession?
    private(set) var current = MetricSnapshot()
    private(set) var samplingPaused = false
    var errorMessage: String?
    let storage: DatasetStorage
    @ObservationIgnored private let providers: [any MetricProvider]
    @ObservationIgnored private let motion: MotionMetricProvider
    @ObservationIgnored private var timer: Task<Void, Never>?
    @ObservationIgnored private var state = "unknown"
    @ObservationIgnored private let now: () -> Date

    init(storage: DatasetStorage, providers: [any MetricProvider]? = nil, now: @escaping () -> Date = Date.init) {
        self.storage = storage
        self.now = now
        motion = MotionMetricProvider()
        self.providers = providers ?? [BatteryMetricProvider(), ScreenMetricProvider(), ThermalMetricProvider(),
            NetworkMetricProvider(), DeviceMetricProvider(), LifecycleMetricProvider()]
        do { session = try storage.activeSession() }
        catch { errorMessage = "Could not restore the active session: \(error.localizedDescription)" }
    }

    func refresh() {
        var snapshot = MetricSnapshot()
        for provider in providers { provider.update(&snapshot) }
        motion.update(&snapshot)
        if state != "unknown" { snapshot.appState = state }
        current = snapshot
    }

    func start(interval: TimeInterval) {
        guard session == nil, [10.0, 30, 60, 120].contains(interval) else { return }
        let newSession = CollectionSession(startedAt: now(), samplingInterval: interval)
        motion.start()
        do {
            try storage.transaction {
                storage.context.insert(newSession)
                appendEvent("session_started", to: newSession)
                appendSample(to: newSession)
            }
            session = newSession
            samplingPaused = false
            schedule()
        } catch { fail(error); motion.stop() }
    }

    func stop() {
        guard let session else { return }
        timer?.cancel()
        timer = nil
        do {
            try storage.transaction {
                appendSample(to: session)
                session.endedAt = now()
                appendEvent("session_stopped", to: session)
            }
            self.session = nil
            samplingPaused = false
            motion.stop()
        } catch { fail(error) }
    }

    func lifecycleChanged(to newState: String) {
        guard state != newState else { return }
        state = newState
        timer?.cancel()
        timer = nil
        if newState == "active" {
            for provider in providers { provider.start() }
            if session != nil { motion.start() }
        }
        refresh()
        if let session {
            do {
                try storage.transaction {
                    let event = newState == "active" ? "app_became_active" :
                        newState == "background" ? "app_entered_background" : "app_became_inactive"
                    appendEvent(event, to: session)
                    // Only actual observations at transition time. Never backfill a suspended interval.
                    appendSample(to: session)
                    if newState == "active" { appendEvent("sampling_resumed", to: session) }
                }
                samplingPaused = false
            } catch { fail(error) }
        }
        if newState == "background" {
            for provider in providers { provider.stop() }
            motion.stop()
        }
        if newState == "active", !samplingPaused { schedule() }
    }

    func retrySampling() {
        guard session != nil, state == "active" else { return }
        do {
            try storage.transaction {
                if let session {
                    appendEvent("sampling_resumed", to: session)
                    appendSample(to: session)
                }
            }
            samplingPaused = false
            errorMessage = nil
            schedule()
        } catch { fail(error) }
    }

    private func schedule() {
        timer?.cancel()
        guard let interval = session?.samplingInterval, state == "active" else { return }
        timer = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(interval)) }
                catch { return }
                guard let self, !Task.isCancelled, self.state == "active", let session = self.session else { return }
                do { try self.storage.transaction { self.appendSample(to: session) } }
                catch { self.fail(error); return }
            }
        }
    }

    private func appendSample(to session: CollectionSession) {
        refresh()
        let sample = TelemetrySample(sessionID: session.id, startedAt: session.startedAt, timestamp: now(), metrics: current)
        storage.context.insert(sample)
        session.sampleCount += 1
    }

    private func appendEvent(_ name: String, to session: CollectionSession) {
        storage.context.insert(LifecycleEvent(sessionID: session.id, timestamp: now(), name: name, appState: state))
    }

    private func fail(_ error: Error) {
        timer?.cancel()
        timer = nil
        samplingPaused = true
        errorMessage = "Storage error. Sampling is paused; the last transaction was not saved. \(error.localizedDescription)"
    }
}
