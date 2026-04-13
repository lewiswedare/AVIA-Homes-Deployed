import Foundation

nonisolated struct ClientUser: Identifiable, Sendable {
    var id: String
    var firstName: String
    var lastName: String
    var email: String
    var phone: String
    var address: String
    var homeDesign: String
    var lotNumber: String
    var contractDate: Date
    var profileCompleted: Bool
    var role: UserRole
    var assignedClientIds: [String]
    var assignedStaffId: String?
    var salesPartnerId: String?
    var displayTitle: String?
    var avatarUrl: String?

    var fullName: String { "\(firstName) \(lastName)" }

    var initials: String {
        let f = firstName.prefix(1)
        let l = lastName.prefix(1)
        return "\(f)\(l)"
    }

    var isClient: Bool { role == .client }
    var isStaff: Bool { role == .staff }
    var isAdmin: Bool { role.isAdmin }
    var isPartner: Bool { role == .partner }

    static let empty = ClientUser(
        id: "",
        firstName: "",
        lastName: "",
        email: "",
        phone: "",
        address: "",
        homeDesign: "",
        lotNumber: "",
        contractDate: .now,
        profileCompleted: false,
        role: .client,
        assignedClientIds: [],
        assignedStaffId: nil,
        salesPartnerId: nil,
        displayTitle: nil,
        avatarUrl: nil
    )
}
