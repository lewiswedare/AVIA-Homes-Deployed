import Foundation

nonisolated struct BuildReminder: Identifiable, Sendable {
    let id: String
    let buildId: String
    let milestoneId: String?
    let clientId: String
    let title: String
    let message: String
    let reminderDate: Date?
    var isRead: Bool
    let createdAt: Date?
}
