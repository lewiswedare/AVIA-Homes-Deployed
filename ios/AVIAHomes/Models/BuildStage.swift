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
    let estimatedStartDate: Date?
    let estimatedEndDate: Date?
    let actualStartDate: Date?
    let actualEndDate: Date?

    nonisolated enum StageStatus: String, Sendable {
        case completed = "Completed"
        case inProgress = "In Progress"
        case upcoming = "Upcoming"
        case delayed = "Delayed"
    }

    init(id: String, name: String, description: String, status: StageStatus, progress: Double, startDate: Date? = nil, completionDate: Date? = nil, notes: String? = nil, photoCount: Int = 0, estimatedStartDate: Date? = nil, estimatedEndDate: Date? = nil, actualStartDate: Date? = nil, actualEndDate: Date? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.status = status
        self.progress = progress
        self.startDate = startDate
        self.completionDate = completionDate
        self.notes = notes
        self.photoCount = photoCount
        self.estimatedStartDate = estimatedStartDate
        self.estimatedEndDate = estimatedEndDate
        self.actualStartDate = actualStartDate
        self.actualEndDate = actualEndDate
    }

    static let samples: [BuildStage] = []
}
