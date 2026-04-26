import Foundation

nonisolated enum ClientActivityKind: String, Codable, Sendable, CaseIterable {
    case designView = "design_view"
    case floorplanDownload = "floorplan_download"
    case specRangeView = "spec_range_view"
    case packageView = "package_view"
    case enquirySent = "enquiry_sent"

    var icon: String {
        switch self {
        case .designView: return "house.fill"
        case .floorplanDownload: return "arrow.down.doc.fill"
        case .specRangeView: return "square.stack.3d.up.fill"
        case .packageView: return "shippingbox.fill"
        case .enquirySent: return "paperplane.fill"
        }
    }

    var label: String {
        switch self {
        case .designView: return "Viewed design"
        case .floorplanDownload: return "Downloaded floorplan"
        case .specRangeView: return "Viewed spec range"
        case .packageView: return "Viewed package"
        case .enquirySent: return "Sent enquiry"
        }
    }
}

struct ClientActivity: Identifiable, Hashable {
    let id: String
    let clientId: String
    let kind: ClientActivityKind
    let referenceId: String
    let referenceName: String
    let createdAt: Date
}

nonisolated struct ClientActivityRow: Codable, Sendable {
    let id: String
    let client_id: String
    let kind: String
    let reference_id: String
    let reference_name: String
    let created_at: String?

    init(activity: ClientActivity) {
        self.id = activity.id
        self.client_id = activity.clientId
        self.kind = activity.kind.rawValue
        self.reference_id = activity.referenceId
        self.reference_name = activity.referenceName
        self.created_at = ISO8601DateFormatter().string(from: activity.createdAt)
    }

    func toActivity() -> ClientActivity? {
        guard let kind = ClientActivityKind(rawValue: kind) else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: created_at ?? "") ?? ISO8601DateFormatter().date(from: created_at ?? "") ?? .now
        return ClientActivity(
            id: id,
            clientId: client_id,
            kind: kind,
            referenceId: reference_id,
            referenceName: reference_name,
            createdAt: date
        )
    }
}
