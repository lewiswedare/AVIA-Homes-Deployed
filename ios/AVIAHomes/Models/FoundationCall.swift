import Foundation
import SwiftUI

// MARK: - Status

nonisolated enum FoundationCallStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case pending
    case scheduled
    case completed
    case cancelled
    case noShow = "no_show"
    case rescheduled

    nonisolated var id: String { rawValue }

    var label: String {
        switch self {
        case .pending: return "Not Scheduled"
        case .scheduled: return "Scheduled"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .noShow: return "No Show"
        case .rescheduled: return "Rescheduled"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "video.badge.plus"
        case .scheduled: return "video.fill"
        case .completed: return "checkmark.seal.fill"
        case .cancelled: return "xmark.circle.fill"
        case .noShow: return "person.fill.xmark"
        case .rescheduled: return "arrow.triangle.2.circlepath"
        }
    }

    var color: Color {
        switch self {
        case .pending: return AVIATheme.textTertiary
        case .scheduled: return AVIATheme.timelessBrown
        case .completed: return AVIATheme.success
        case .cancelled: return AVIATheme.warning
        case .noShow: return AVIATheme.warning
        case .rescheduled: return AVIATheme.timelessBrown.opacity(0.8)
        }
    }
}

// MARK: - Model

struct FoundationCall: Identifiable, Hashable {
    let id: String
    let clientId: String
    var organizerId: String?
    var status: FoundationCallStatus
    var scheduledAt: Date?
    var durationMinutes: Int?
    var meetingURL: String?
    var calBookingId: String?
    var calBookingUid: String?
    var calEventType: String?
    var attendeeEmail: String?
    var attendeeName: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    var isUpcoming: Bool {
        guard status == .scheduled, let when = scheduledAt else { return false }
        return when > .now
    }
}

nonisolated struct FoundationCallRow: Codable, Sendable {
    let id: String
    let client_id: String
    let organizer_id: String?
    let status: String
    let scheduled_at: String?
    let duration_minutes: Int?
    let meeting_url: String?
    let cal_booking_id: String?
    let cal_booking_uid: String?
    let cal_event_type: String?
    let attendee_email: String?
    let attendee_name: String?
    let notes: String?
    let created_at: String?
    let updated_at: String?

    init(call: FoundationCall) {
        let iso = ISO8601DateFormatter()
        self.id = call.id
        self.client_id = call.clientId
        self.organizer_id = call.organizerId
        self.status = call.status.rawValue
        self.scheduled_at = call.scheduledAt.map { iso.string(from: $0) }
        self.duration_minutes = call.durationMinutes
        self.meeting_url = call.meetingURL
        self.cal_booking_id = call.calBookingId
        self.cal_booking_uid = call.calBookingUid
        self.cal_event_type = call.calEventType
        self.attendee_email = call.attendeeEmail
        self.attendee_name = call.attendeeName
        self.notes = call.notes
        self.created_at = iso.string(from: call.createdAt)
        self.updated_at = iso.string(from: call.updatedAt)
    }

    func toCall() -> FoundationCall {
        FoundationCall(
            id: id,
            clientId: client_id,
            organizerId: organizer_id,
            status: FoundationCallStatus(rawValue: status) ?? .pending,
            scheduledAt: ClientCRMProfileRow.parse(scheduled_at),
            durationMinutes: duration_minutes,
            meetingURL: meeting_url,
            calBookingId: cal_booking_id,
            calBookingUid: cal_booking_uid,
            calEventType: cal_event_type,
            attendeeEmail: attendee_email,
            attendeeName: attendee_name,
            notes: notes,
            createdAt: ClientCRMProfileRow.parse(created_at) ?? .now,
            updatedAt: ClientCRMProfileRow.parse(updated_at) ?? .now
        )
    }
}
