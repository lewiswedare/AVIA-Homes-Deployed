import Foundation

nonisolated struct InvoiceRow: Identifiable, Codable, Sendable {
    let id: String
    var contract_id: String?
    var client_id: String
    var admin_id: String?
    var invoice_number: String?
    var description: String?
    var amount: Double?
    var package_price: Double?
    var status: String
    var due_date: String?
    var paid_at: String?
    var invoice_url: String?
    var notes: String?
    let created_at: String?
    let updated_at: String?

    var statusEnum: InvoiceStatus {
        InvoiceStatus(rawValue: status) ?? .draft
    }

    var displayStatus: String {
        statusEnum.displayLabel
    }

    var formattedAmount: String {
        guard let amount else { return "—" }
        return String(format: "$%.2f", amount)
    }

    var formattedDueDate: String {
        guard let due_date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: due_date) else { return due_date }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

nonisolated enum InvoiceStatus: String, Codable, Sendable, CaseIterable {
    case draft
    case sent
    case paid
    case overdue
    case cancelled

    var displayLabel: String {
        switch self {
        case .draft: "Draft"
        case .sent: "Sent"
        case .paid: "Paid"
        case .overdue: "Overdue"
        case .cancelled: "Cancelled"
        }
    }

    var icon: String {
        switch self {
        case .draft: "doc.text.fill"
        case .sent: "paperplane.fill"
        case .paid: "checkmark.circle.fill"
        case .overdue: "exclamationmark.triangle.fill"
        case .cancelled: "xmark.circle.fill"
        }
    }
}
