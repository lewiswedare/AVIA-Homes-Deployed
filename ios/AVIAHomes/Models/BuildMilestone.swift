import Foundation

nonisolated struct BuildMilestone: Identifiable, Sendable {
    let id: String
    let buildStageId: String
    let buildId: String
    let title: String
    let description: String
    let dueDate: Date?
    let completedAt: Date?
    let status: MilestoneStatus
    let requiresClientAction: Bool
    let clientActionDescription: String?
    let createdAt: Date?

    nonisolated enum MilestoneStatus: String, Sendable, CaseIterable {
        case pending
        case completed
        case overdue
    }

    var isOverdue: Bool {
        guard status != .completed else { return false }
        guard let dueDate else { return false }
        return dueDate < Date.now
    }

    var isActionRequired: Bool {
        requiresClientAction && status != .completed
    }
}
