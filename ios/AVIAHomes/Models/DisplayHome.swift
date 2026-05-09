import Foundation
import SwiftUI

// MARK: - Listing

struct DisplayHome: Identifiable, Hashable, Sendable {
    let id: String
    var name: String
    var estate: String
    var address: String
    var suburb: String
    var description: String
    var bedrooms: Int
    var bathrooms: Int
    var garages: Int
    var squareMeters: Double?
    var homeDesignId: String?
    var imageURLs: [String]
    var features: [String]
    var openingHours: String
    var contactPhone: String
    var isActive: Bool
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    var primaryImageURL: String? { imageURLs.first }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    nonisolated static func == (lhs: DisplayHome, rhs: DisplayHome) -> Bool {
        lhs.id == rhs.id
    }

    static var blank: DisplayHome {
        DisplayHome(
            id: UUID().uuidString,
            name: "",
            estate: "",
            address: "",
            suburb: "",
            description: "",
            bedrooms: 4,
            bathrooms: 2,
            garages: 2,
            squareMeters: nil,
            homeDesignId: nil,
            imageURLs: [],
            features: [],
            openingHours: "Sat–Sun 10am–4pm",
            contactPhone: "",
            isActive: true,
            sortOrder: 0,
            createdAt: .now,
            updatedAt: .now
        )
    }
}

nonisolated struct DisplayHomeRow: Codable, Sendable {
    let id: String
    let name: String
    let estate: String?
    let address: String?
    let suburb: String?
    let description: String?
    let bedrooms: Int?
    let bathrooms: Int?
    let garages: Int?
    let square_meters: Double?
    let home_design_id: String?
    let image_urls: [String]?
    let features: [String]?
    let opening_hours: String?
    let contact_phone: String?
    let is_active: Bool?
    let sort_order: Int?
    let created_at: String?
    let updated_at: String?

    init(from home: DisplayHome) {
        let iso = ISO8601DateFormatter()
        self.id = home.id
        self.name = home.name
        self.estate = home.estate.isEmpty ? nil : home.estate
        self.address = home.address.isEmpty ? nil : home.address
        self.suburb = home.suburb.isEmpty ? nil : home.suburb
        self.description = home.description.isEmpty ? nil : home.description
        self.bedrooms = home.bedrooms
        self.bathrooms = home.bathrooms
        self.garages = home.garages
        self.square_meters = home.squareMeters
        self.home_design_id = home.homeDesignId
        self.image_urls = home.imageURLs
        self.features = home.features
        self.opening_hours = home.openingHours.isEmpty ? nil : home.openingHours
        self.contact_phone = home.contactPhone.isEmpty ? nil : home.contactPhone
        self.is_active = home.isActive
        self.sort_order = home.sortOrder
        self.created_at = nil
        self.updated_at = iso.string(from: .now)
    }

    func toDisplayHome() -> DisplayHome {
        DisplayHome(
            id: id,
            name: name,
            estate: estate ?? "",
            address: address ?? "",
            suburb: suburb ?? "",
            description: description ?? "",
            bedrooms: bedrooms ?? 0,
            bathrooms: bathrooms ?? 0,
            garages: garages ?? 0,
            squareMeters: square_meters,
            homeDesignId: home_design_id,
            imageURLs: image_urls ?? [],
            features: features ?? [],
            openingHours: opening_hours ?? "",
            contactPhone: contact_phone ?? "",
            isActive: is_active ?? true,
            sortOrder: sort_order ?? 0,
            createdAt: DisplayHomeDateParser.parse(created_at) ?? .now,
            updatedAt: DisplayHomeDateParser.parse(updated_at) ?? .now
        )
    }
}

// MARK: - Visit

nonisolated enum DisplayHomeVisitStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case pending
    case confirmed
    case completed
    case cancelled
    case noShow = "no_show"
    case rescheduled

    nonisolated var id: String { rawValue }

    var label: String {
        switch self {
        case .pending: return "Requested"
        case .confirmed: return "Confirmed"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .noShow: return "No Show"
        case .rescheduled: return "Rescheduled"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock.badge.questionmark"
        case .confirmed: return "checkmark.seal.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        case .noShow: return "person.fill.xmark"
        case .rescheduled: return "arrow.triangle.2.circlepath"
        }
    }

    var color: Color {
        switch self {
        case .pending: return AVIATheme.warning
        case .confirmed: return AVIATheme.timelessBrown
        case .completed: return AVIATheme.success
        case .cancelled: return AVIATheme.destructive
        case .noShow: return AVIATheme.textTertiary
        case .rescheduled: return AVIATheme.timelessBrown.opacity(0.8)
        }
    }
}

struct DisplayHomeVisit: Identifiable, Hashable, Sendable {
    let id: String
    var displayHomeId: String
    var clientId: String?
    var requestedAt: Date
    var durationMinutes: Int
    var status: DisplayHomeVisitStatus
    var attendeeName: String
    var attendeeEmail: String
    var attendeePhone: String
    var partySize: Int
    var notes: String
    var assignedStaffId: String?
    var adminNotes: String
    var confirmedAt: Date?
    var completedAt: Date?
    var cancelledAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var isUpcoming: Bool {
        (status == .pending || status == .confirmed) && requestedAt > .now
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    nonisolated static func == (lhs: DisplayHomeVisit, rhs: DisplayHomeVisit) -> Bool {
        lhs.id == rhs.id
    }
}

nonisolated struct DisplayHomeVisitRow: Codable, Sendable {
    let id: String
    let display_home_id: String
    let client_id: String?
    let requested_at: String
    let duration_minutes: Int?
    let status: String
    let attendee_name: String?
    let attendee_email: String?
    let attendee_phone: String?
    let party_size: Int?
    let notes: String?
    let assigned_staff_id: String?
    let admin_notes: String?
    let confirmed_at: String?
    let completed_at: String?
    let cancelled_at: String?
    let created_at: String?
    let updated_at: String?

    init(from visit: DisplayHomeVisit) {
        let iso = ISO8601DateFormatter()
        self.id = visit.id
        self.display_home_id = visit.displayHomeId
        self.client_id = visit.clientId
        self.requested_at = iso.string(from: visit.requestedAt)
        self.duration_minutes = visit.durationMinutes
        self.status = visit.status.rawValue
        self.attendee_name = visit.attendeeName.isEmpty ? nil : visit.attendeeName
        self.attendee_email = visit.attendeeEmail.isEmpty ? nil : visit.attendeeEmail
        self.attendee_phone = visit.attendeePhone.isEmpty ? nil : visit.attendeePhone
        self.party_size = visit.partySize
        self.notes = visit.notes.isEmpty ? nil : visit.notes
        self.assigned_staff_id = visit.assignedStaffId
        self.admin_notes = visit.adminNotes.isEmpty ? nil : visit.adminNotes
        self.confirmed_at = visit.confirmedAt.map { iso.string(from: $0) }
        self.completed_at = visit.completedAt.map { iso.string(from: $0) }
        self.cancelled_at = visit.cancelledAt.map { iso.string(from: $0) }
        self.created_at = nil
        self.updated_at = iso.string(from: .now)
    }

    func toVisit() -> DisplayHomeVisit {
        DisplayHomeVisit(
            id: id,
            displayHomeId: display_home_id,
            clientId: client_id,
            requestedAt: DisplayHomeDateParser.parse(requested_at) ?? .now,
            durationMinutes: duration_minutes ?? 45,
            status: DisplayHomeVisitStatus(rawValue: status) ?? .pending,
            attendeeName: attendee_name ?? "",
            attendeeEmail: attendee_email ?? "",
            attendeePhone: attendee_phone ?? "",
            partySize: party_size ?? 1,
            notes: notes ?? "",
            assignedStaffId: assigned_staff_id,
            adminNotes: admin_notes ?? "",
            confirmedAt: DisplayHomeDateParser.parse(confirmed_at),
            completedAt: DisplayHomeDateParser.parse(completed_at),
            cancelledAt: DisplayHomeDateParser.parse(cancelled_at),
            createdAt: DisplayHomeDateParser.parse(created_at) ?? .now,
            updatedAt: DisplayHomeDateParser.parse(updated_at) ?? .now
        )
    }
}

// MARK: - Date helper

nonisolated enum DisplayHomeDateParser {
    static func parse(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: string) { return date }
        let fallback = ISO8601DateFormatter()
        return fallback.date(from: string)
    }
}
