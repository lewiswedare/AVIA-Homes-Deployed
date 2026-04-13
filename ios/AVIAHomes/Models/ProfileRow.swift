import Foundation

nonisolated struct ProfileRow: Codable, Sendable {
    let id: String
    var first_name: String
    var last_name: String
    var email: String
    var phone: String
    var address: String
    var home_design: String
    var lot_number: String
    var contract_date: String?
    var profile_completed: Bool
    var role: String
    var assigned_client_ids: [String]
    var assigned_staff_id: String?
    var sales_partner_id: String?
    var is_active: Bool?
    var created_at: String?
    var updated_at: String?

    func toClientUser() -> ClientUser {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallbackFormatter = ISO8601DateFormatter()
        let date = contract_date.flatMap { formatter.date(from: $0) ?? fallbackFormatter.date(from: $0) } ?? .now
        return ClientUser(
            id: id,
            firstName: first_name,
            lastName: last_name,
            email: email,
            phone: phone,
            address: address,
            homeDesign: home_design,
            lotNumber: lot_number,
            contractDate: date,
            profileCompleted: profile_completed,
            role: UserRole(rawValue: role) ?? .client,
            assignedClientIds: assigned_client_ids,
            assignedStaffId: assigned_staff_id,
            salesPartnerId: sales_partner_id
        )
    }
}

nonisolated struct ProfileUpdatePayload: Encodable, Sendable {
    let first_name: String
    let last_name: String
    let phone: String
    let address: String
    let email: String
    let role: String
    let profile_completed: Bool
}

nonisolated struct ProfileUpsertRow: Encodable, Sendable {
    let id: String
    let first_name: String
    let last_name: String
    let email: String
    let phone: String
    let address: String
    let home_design: String
    let lot_number: String
    let contract_date: String?
    let profile_completed: Bool
    let role: String
    let assigned_client_ids: [String]
    let assigned_staff_id: String?
    let sales_partner_id: String?

    init(from user: ClientUser) {
        let iso = ISO8601DateFormatter()
        id = user.id
        first_name = user.firstName
        last_name = user.lastName
        email = user.email
        phone = user.phone
        address = user.address
        home_design = user.homeDesign
        lot_number = user.lotNumber
        contract_date = iso.string(from: user.contractDate)
        profile_completed = user.profileCompleted
        role = user.role.rawValue
        assigned_client_ids = user.assignedClientIds
        assigned_staff_id = user.assignedStaffId
        sales_partner_id = user.salesPartnerId
    }
}
