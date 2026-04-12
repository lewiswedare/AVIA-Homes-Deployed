import Foundation

nonisolated enum UserRole: String, Codable, CaseIterable, Sendable {
    case pending = "Pending"
    case client = "Client"
    case staff = "Staff"
    case admin = "Admin"
    case partner = "Partner"
    case salesAdmin = "SalesAdmin"
    case salesPartner = "SalesPartner"

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
        case .admin, .salesAdmin: "person.badge.shield.checkmark.fill"
        case .partner, .salesPartner: "person.2.fill"
        }
    }

    var description: String {
        switch self {
        case .pending: "Awaiting role assignment"
        case .client: "View and manage your home build"
        case .staff: "View and add info to assigned client builds"
        case .admin, .salesAdmin: "Full access to update and edit all data"
        case .partner, .salesPartner: "View associated client portfolios"
        }
    }

    var canEditBuildDetails: Bool {
        self == .staff || self == .admin || self == .salesAdmin
    }

    var canViewAllClients: Bool {
        self == .admin || self == .salesAdmin
    }

    var canEditAllData: Bool {
        self == .admin || self == .salesAdmin
    }

    var canManageUsers: Bool {
        self == .admin || self == .salesAdmin
    }

    var canViewPackages: Bool {
        self == .staff || self == .admin || self == .partner || self == .salesAdmin || self == .salesPartner
    }

    var canManagePackages: Bool {
        self == .admin || self == .salesAdmin
    }

    var canAllocatePackages: Bool {
        self == .admin || self == .partner || self == .salesAdmin || self == .salesPartner
    }

    var isPending: Bool {
        self == .pending
    }

    var isAnyStaffRole: Bool {
        self == .staff || self == .admin || self == .salesAdmin
    }

    static var assignableRoles: [UserRole] {
        [.client, .staff, .admin, .partner, .salesAdmin, .salesPartner]
    }
}
