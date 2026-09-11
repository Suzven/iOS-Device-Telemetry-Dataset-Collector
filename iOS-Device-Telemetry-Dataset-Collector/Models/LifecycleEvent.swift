import Foundation
import SwiftData

@Model
final class LifecycleEvent {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var timestamp: Date
    var name: String
    var appState: String

    init(sessionID: UUID, timestamp: Date = Date(), name: String, appState: String) {
        id = UUID()
        self.sessionID = sessionID
        self.timestamp = timestamp
        self.name = name
        self.appState = appState
    }
}
