import Foundation
import SwiftData

@Model
final class CollectionSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var sampleCount: Int
    var optionalNote: String?
    var samplingInterval: TimeInterval

    init(id: UUID = UUID(), startedAt: Date = Date(), samplingInterval: TimeInterval = 60) {
        self.id = id
        self.startedAt = startedAt
        self.samplingInterval = samplingInterval
        sampleCount = 0
    }
}
