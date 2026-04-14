import Foundation

nonisolated struct ContractSignatureRow: Identifiable, Codable, Sendable {
    let id: String
    let eoi_id: String
    let package_assignment_id: String
    let client_id: String

    var contract_document_url: String?
    var contract_uploaded_by: String?
    var contract_uploaded_at: String?

    var signature_image_url: String?
    var signed_at: String?
    var signer_name: String?
    var signer_ip: String?

    var signed_document_url: String?
    var status: String

    let created_at: String?
    let updated_at: String?
}
