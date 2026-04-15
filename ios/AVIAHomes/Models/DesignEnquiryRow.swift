import Foundation

nonisolated struct DesignEnquiryInsertRow: Encodable, Sendable {
    let id: String
    let design_name: String
    let full_name: String
    let email: String
    let phone: String
    let message: String?
    let created_at: String

    init(designName: String, fullName: String, email: String, phone: String, message: String?) {
        self.id = UUID().uuidString.lowercased()
        self.design_name = designName
        self.full_name = fullName
        self.email = email
        self.phone = phone
        self.message = message
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.created_at = formatter.string(from: Date())
    }
}
