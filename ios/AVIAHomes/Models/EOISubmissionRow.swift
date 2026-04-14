import Foundation

nonisolated struct EOISubmissionRow: Identifiable, Codable, Sendable {
    let id: String
    let package_assignment_id: String
    let package_id: String
    let client_id: String

    var lot_number: String
    var estate_name: String
    var street_suburb: String?
    var occupancy_type: String
    var specification_tier: String?
    var facade_selection: String?

    var buyer1_name: String
    var buyer1_email: String
    var buyer1_address: String
    var buyer1_phone: String

    var buyer2_name: String?
    var buyer2_email: String?
    var buyer2_address: String?
    var buyer2_phone: String?

    var solicitor_company: String
    var solicitor_name: String
    var solicitor_email: String
    var solicitor_address: String
    var solicitor_phone: String

    var status: String
    var admin_notes: String?
    var reviewed_by: String?
    var reviewed_at: String?

    let created_at: String?
    let updated_at: String?
}
