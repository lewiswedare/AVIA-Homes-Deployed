import Foundation

nonisolated enum UserRole: String, Codable, CaseIterable, Sendable {
    case pending = "Pending"
    case client = "Client"
    case staff = "Staff"
    case admin = "Admin"
    case partner = "Partner"

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = UserRole(rawValue: rawValue) ?? .client
    }

    var icon: String {
        switch self {
        case .pending: "clock.fill"
        case .client: "person.fill"
        case .staff: "hammer.fill"
        case .admin: "person.badge.shield.checkmark.fill"
        case .partner: "person.2.fill"
        }
    }

    var description: String {
        switch self {
        case .pending: "Awaiting role assignment"
        case .client: "View and manage your home build"
        case .staff: "View and add info to assigned client builds"
        case .admin: "Full access to update and edit all data"
        case .partner: "View associated client portfolios"
        }
    }

    var canEditBuildDetails: Bool {
        self == .staff || self == .admin
    }

    var canViewAllClients: Bool {
        self == .admin
    }

    var canEditAllData: Bool {
        self == .admin
    }

    var canManageUsers: Bool {
        self == .admin
    }

    var canViewPackages: Bool {
        self == .staff || self == .admin || self == .partner
    }

    var canManagePackages: Bool {
        self == .admin
    }

    var canAllocatePackages: Bool {
        self == .admin || self == .partner
    }

    var isPending: Bool {
        self == .pending
    }

    var isAnyStaffRole: Bool {
        self == .staff || self == .admin
    }

    static var assignableRoles: [UserRole] {
        [.client, .staff, .admin, .partner]
    }
}
