import Foundation

nonisolated enum NotificationType: String, Codable, Sendable {
    case packageShared = "package_shared"
    case packageApproved = "package_approved"
    case packageDeclined = "package_declined"
    case packageAccepted = "package_accepted"
    case depositInvoice = "deposit_invoice"
    case depositReceived = "deposit_received"
    case handoverTriggered = "handover_triggered"
    case roleAssigned = "role_assigned"
    case requestSubmitted = "request_submitted"
    case requestResponse = "request_response"
    case buildUpdate = "build_update"
    case newMessage = "new_message"
    case upgradeQuoted = "upgrade_quoted"
    case colourSelectionSubmitted = "colour_selection_submitted"
    case specTierChanged = "spec_tier_changed"
    case documentAdded = "document_added"

    var icon: String {
        switch self {
        case .packageShared: "square.and.arrow.up.fill"
        case .packageApproved: "checkmark.circle.fill"
        case .packageDeclined: "xmark.circle.fill"
        case .packageAccepted: "hand.thumbsup.fill"
        case .depositInvoice: "banknote.fill"
        case .depositReceived: "checkmark.seal.fill"
        case .handoverTriggered: "arrow.right.arrow.left"
        case .roleAssigned: "person.badge.key.fill"
        case .requestSubmitted: "bubble.left.fill"
        case .requestResponse: "arrowshape.turn.up.left.fill"
        case .buildUpdate: "hammer.fill"
        case .newMessage: "message.fill"
        case .upgradeQuoted: "dollarsign.circle.fill"
        case .colourSelectionSubmitted: "paintpalette.fill"
        case .specTierChanged: "arrow.up.circle.fill"
        case .documentAdded: "doc.text.fill"
        }
    }

    var color: String {
        switch self {
        case .packageShared: "teal"
        case .packageApproved: "success"
        case .packageDeclined: "destructive"
        case .packageAccepted: "success"
        case .depositInvoice: "warning"
        case .depositReceived: "success"
        case .handoverTriggered: "teal"
        case .roleAssigned: "teal"
        case .requestSubmitted: "warning"
        case .requestResponse: "teal"
        case .buildUpdate: "teal"
        case .newMessage: "teal"
        case .upgradeQuoted: "teal"
        case .colourSelectionSubmitted: "teal"
        case .specTierChanged: "warning"
        case .documentAdded: "teal"
        }
    }
}

nonisolated struct AppNotification: Identifiable, Sendable, Hashable {
    let id: String
    let recipientId: String
    let senderId: String?
    let senderName: String
    let type: NotificationType
    let title: String
    let message: String
    let referenceId: String?
    let referenceType: String?
    let createdAt: Date
    var isRead: Bool

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    nonisolated static func == (lhs: AppNotification, rhs: AppNotification) -> Bool {
        lhs.id == rhs.id && lhs.isRead == rhs.isRead
    }

    var pushTitle: String {
        if !title.isEmpty { return title }
        switch type {
        case .newMessage: return "New Message"
        case .upgradeQuoted: return "Upgrade Quoted"
        case .specTierChanged: return "Spec Tier Updated"
        case .colourSelectionSubmitted: return "Colour Selection Submitted"
        case .documentAdded: return "New Document"
        case .buildUpdate: return "Build Assigned"
        case .packageShared: return "Package Shared"
        case .packageApproved: return "Package Approved"
        case .packageDeclined: return "Package Declined"
        case .packageAccepted: return "Package Accepted"
        case .depositInvoice: return "Deposit Invoice Ready"
        case .depositReceived: return "Deposit Received"
        case .handoverTriggered: return "Build Handover"
        case .roleAssigned: return "Role Updated"
        case .requestSubmitted: return "New Request"
        case .requestResponse: return "Request Response"
        }
    }

    var pushBody: String {
        if !message.isEmpty { return message }
        switch type {
        case .newMessage: return "You have a new message"
        case .upgradeQuoted: return "Your upgrade request has been quoted"
        case .specTierChanged: return "Your spec tier has been updated"
        case .colourSelectionSubmitted: return "Your colour selection has been submitted"
        case .documentAdded: return "A document has been added to your build"
        case .buildUpdate: return "You have been assigned to a new build"
        case .packageShared: return "A package has been shared with you"
        case .packageApproved: return "Your package response has been approved"
        case .packageDeclined: return "Your package response has been declined"
        case .packageAccepted: return "A client has accepted a package"
        case .depositInvoice: return "Your deposit invoice is ready to view"
        case .depositReceived: return "Your deposit has been received"
        case .handoverTriggered: return "Your build has moved to construction phase"
        case .roleAssigned: return "Your role has been updated"
        case .requestSubmitted: return "A new request has been submitted"
        case .requestResponse: return "You have a new response to your request"
        }
    }

    static let samples: [AppNotification] = []
}
