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
    var display_title: String?
    var avatar_url: String?
    var is_active: Bool?
    var created_at: String?
    var updated_at: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case id, first_name, last_name, email, phone, address, home_design, lot_number
        case contract_date, profile_completed, role, assigned_client_ids
        case assigned_staff_id, sales_partner_id, display_title, avatar_url
        case is_active, created_at, updated_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        first_name = try container.decode(String.self, forKey: .first_name)
        last_name = try container.decode(String.self, forKey: .last_name)
        email = try container.decode(String.self, forKey: .email)
        phone = (try? container.decode(String.self, forKey: .phone)) ?? ""
        address = (try? container.decode(String.self, forKey: .address)) ?? ""
        home_design = (try? container.decode(String.self, forKey: .home_design)) ?? ""
        lot_number = (try? container.decode(String.self, forKey: .lot_number)) ?? ""
        contract_date = try? container.decode(String.self, forKey: .contract_date)
        profile_completed = (try? container.decode(Bool.self, forKey: .profile_completed)) ?? false
        role = (try? container.decode(String.self, forKey: .role)) ?? "Client"
        assigned_client_ids = (try? container.decode([String].self, forKey: .assigned_client_ids)) ?? []
        assigned_staff_id = try? container.decode(String.self, forKey: .assigned_staff_id)
        sales_partner_id = try? container.decode(String.self, forKey: .sales_partner_id)
        display_title = try? container.decode(String.self, forKey: .display_title)
        avatar_url = try? container.decode(String.self, forKey: .avatar_url)
        is_active = try? container.decode(Bool.self, forKey: .is_active)
        created_at = try? container.decode(String.self, forKey: .created_at)
        updated_at = try? container.decode(String.self, forKey: .updated_at)
    }

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
            salesPartnerId: sales_partner_id,
            displayTitle: display_title,
            avatarUrl: avatar_url
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
    let display_title: String?
    let avatar_url: String?

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
        display_title = user.displayTitle
        avatar_url = user.avatarUrl
    }
}
