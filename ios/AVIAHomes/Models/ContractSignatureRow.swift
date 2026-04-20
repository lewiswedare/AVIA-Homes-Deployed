import Foundation

nonisolated struct ContractSignatureRow: Identifiable, Codable, Sendable {
    let id: String
    let eoi_id: String
    let package_assignment_id: String
    let client_id: String

    // Original (unsigned) contract uploaded by admin for the client to download & sign.
    var original_contract_url: String?
    var original_contract_uploaded_by: String?
    var original_contract_uploaded_at: String?

    // Signed copy uploaded by the client (or admin) after in-person signing.
    var contract_document_url: String?
    var contract_uploaded_by: String?
    var contract_uploaded_at: String?

    // Legacy in-app signature fields (kept for backwards compatibility with
    // existing rows; no longer written by the app).
    var signature_image_url: String?
    var signed_at: String?
    var signer_name: String?
    var signer_ip: String?
    var signed_document_url: String?

    // Dual-confirmation: both parties must tick "I confirm this is signed"
    // after the in-person signing + PDF upload for the contract to be
    // considered complete.
    var client_confirmed_at: String?
    var admin_confirmed_at: String?
    var admin_confirmed_by: String?

    var status: String

    let created_at: String?
    let updated_at: String?

    // MARK: - Convenience

    var hasDocument: Bool {
        if let url = contract_document_url, !url.isEmpty { return true }
        return false
    }

    var hasOriginalContract: Bool {
        if let url = original_contract_url, !url.isEmpty { return true }
        return false
    }

    var isClientConfirmed: Bool { client_confirmed_at != nil }
    var isAdminConfirmed: Bool { admin_confirmed_at != nil }
    var isFullyConfirmed: Bool { isClientConfirmed && isAdminConfirmed }
}
