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

    var fullName: String { "\(firstName) \(lastName)" }

    var initials: String {
        let f = firstName.prefix(1)
        let l = lastName.prefix(1)
        return "\(f)\(l)"
    }

    var isClient: Bool { role == .client }
    var isStaff: Bool { role == .staff }
    var isAdmin: Bool { role == .admin }
    var isPartner: Bool { role == .partner }

    static let sample = ClientUser(
        id: "demo_client",
        firstName: "Sarah",
        lastName: "Mitchell",
        email: "client@demo.com",
        phone: "0412 345 678",
        address: "14 Coastal Drive, Palmview QLD 4553",
        homeDesign: "Corfu 210",
        lotNumber: "Lot 42",
        contractDate: Calendar.current.date(byAdding: .month, value: -4, to: .now) ?? .now,
        profileCompleted: true,
        role: .client,
        assignedClientIds: [],
        assignedStaffId: "demo_staff",
        salesPartnerId: "demo_partner"
    )

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
        salesPartnerId: nil
    )

    static let sampleStaff = ClientUser(
        id: "demo_staff",
        firstName: "Drew",
        lastName: "Holden",
        email: "staff@demo.com",
        phone: "0468 040 280",
        address: "AVIA Homes HQ, Gold Coast QLD",
        homeDesign: "",
        lotNumber: "",
        contractDate: .now,
        profileCompleted: true,
        role: .staff,
        assignedClientIds: ["demo_client", "2", "3"],
        assignedStaffId: nil,
        salesPartnerId: nil
    )

    static let sampleManager = ClientUser(
        id: "demo_admin",
        firstName: "James",
        lastName: "Wilson",
        email: "admin@demo.com",
        phone: "0412 999 888",
        address: "AVIA Homes HQ, Gold Coast QLD",
        homeDesign: "",
        lotNumber: "",
        contractDate: .now,
        profileCompleted: true,
        role: .admin,
        assignedClientIds: [],
        assignedStaffId: nil,
        salesPartnerId: nil
    )

    static let samplePartner = ClientUser(
        id: "demo_partner",
        firstName: "Michelle",
        lastName: "Park",
        email: "partner@demo.com",
        phone: "0401 222 333",
        address: "Park Property Group, Sunshine Coast QLD",
        homeDesign: "",
        lotNumber: "",
        contractDate: .now,
        profileCompleted: true,
        role: .partner,
        assignedClientIds: ["demo_client", "2"],
        assignedStaffId: nil,
        salesPartnerId: nil
    )
}
