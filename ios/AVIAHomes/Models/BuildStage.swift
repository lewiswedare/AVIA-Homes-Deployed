import Foundation

nonisolated struct BuildStage: Identifiable, Sendable {
    let id: String
    let name: String
    let description: String
    let status: StageStatus
    let progress: Double
    let startDate: Date?
    let completionDate: Date?
    let notes: String?
    let photoCount: Int

    nonisolated enum StageStatus: String, Sendable {
        case completed = "Completed"
        case inProgress = "In Progress"
        case upcoming = "Upcoming"
    }

    static let samples: [BuildStage] = []
}
