import Foundation

nonisolated enum UserRole: String, Codable, CaseIterable, Sendable {
    case pending = "Pending"
    case client = "Client"
    case staff = "Staff"
    case admin = "Admin"
    case partner = "Partner"
    case salesAdmin = "SalesAdmin"
    case salesPartner = "SalesPartner"
    case superAdmin = "SuperAdmin"
    case preConstruction = "PreConstruction"
    case buildingSupport = "BuildingSupport"

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
        case .admin, .salesAdmin, .superAdmin: "person.badge.shield.checkmark.fill"
        case .partner, .salesPartner: "person.2.fill"
        case .preConstruction: "building.fill"
        case .buildingSupport: "wrench.and.screwdriver.fill"
        }
    }

    var description: String {
        switch self {
        case .pending: "Awaiting role assignment"
        case .client: "View and manage your home build"
        case .staff: "View and add info to assigned client builds"
        case .admin, .salesAdmin: "Full access to update and edit all data"
        case .superAdmin: "Full access with staff performance oversight"
        case .partner, .salesPartner: "View associated client portfolios"
        case .preConstruction: "Manage clients during pre-construction phase"
        case .buildingSupport: "Support clients during construction phase"
        }
    }

    var isAdmin: Bool {
        self == .admin || self == .superAdmin
    }

    var isSuperAdmin: Bool {
        self == .superAdmin
    }

    var canEditBuildDetails: Bool {
        self == .staff || self == .admin || self == .salesAdmin || self == .superAdmin || self == .buildingSupport
    }

    var canViewAllClients: Bool {
        self == .admin || self == .salesAdmin || self == .superAdmin
    }

    var canEditAllData: Bool {
        self == .admin || self == .salesAdmin || self == .superAdmin
    }

    var canManageUsers: Bool {
        self == .admin || self == .salesAdmin || self == .superAdmin
    }

    var canViewPackages: Bool {
        self == .staff || self == .admin || self == .partner || self == .salesAdmin || self == .salesPartner || self == .superAdmin
    }

    var canManagePackages: Bool {
        self == .admin || self == .salesAdmin || self == .superAdmin
    }

    var canAllocatePackages: Bool {
        self == .admin || self == .partner || self == .salesAdmin || self == .salesPartner || self == .superAdmin
    }

    var isPending: Bool {
        self == .pending
    }

    var isAnyStaffRole: Bool {
        self == .staff || self == .admin || self == .salesAdmin || self == .superAdmin || self == .preConstruction || self == .buildingSupport
    }

    static var assignableRoles: [UserRole] {
        [.client, .staff, .admin, .partner, .salesAdmin, .salesPartner, .superAdmin, .preConstruction, .buildingSupport]
    }
}
