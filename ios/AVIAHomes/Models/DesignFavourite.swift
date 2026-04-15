import Foundation

nonisolated struct DesignFavourite: Identifiable, Sendable {
    let id: String
    let userId: String
    let designId: String
    let createdAt: Date
}

nonisolated struct DesignFavouriteRow: Codable, Sendable {
    let id: String
    let user_id: String
    let design_id: String
    let created_at: String?

    init(userId: String, designId: String) {
        self.id = UUID().uuidString.lowercased()
        self.user_id = userId
        self.design_id = designId
        self.created_at = nil
    }

    func toDesignFavourite() -> DesignFavourite {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        let date: Date
        if let raw = created_at {
            date = formatter.date(from: raw) ?? fallback.date(from: raw) ?? .now
        } else {
            date = .now
        }
        return DesignFavourite(
            id: id,
            userId: user_id,
            designId: design_id,
            createdAt: date
        )
    }
}

nonisolated struct DesignFavouriteInsert: Codable, Sendable {
    let user_id: String
    let design_id: String
}
