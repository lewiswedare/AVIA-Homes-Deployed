import SwiftUI
import PencilKit
import Supabase

@Observable
class DesignPlanViewModel {
    var planStatus: PlanStatus = .draft
    var correspondence: [PlanCorrespondence] = []
    var planDocuments: [PlanDocument] = []
    var finalDocuments: [PlanDocument] = []
    var newMessageText: String = ""
    var markupDrawing: PKDrawing = PKDrawing()
    var hasUnsavedMarkup: Bool = false
    var showMarkupSubmitted: Bool = false
    var clientConfirmed: Bool = false
    var aviaConfirmed: Bool = false
    var buildId: String = ""
    var currentUserName: String = ""
    var currentUserId: String = ""
    var isClient: Bool = true

    private let supabase = SupabaseService.shared

    var isFinalised: Bool {
        planStatus == .finalised || (clientConfirmed && aviaConfirmed)
    }

    var floorplanImageURL: String {
        HomeDesign.defaultFloorplanURL
    }

    func loadData(buildId: String, userId: String, userName: String, isClient: Bool) async {
        self.buildId = buildId
        self.currentUserId = userId
        self.currentUserName = userName
        self.isClient = isClient
        await loadCorrespondence()
        await loadPlanDocuments()
    }

    private func loadCorrespondence() async {
        guard supabase.isConfigured, !buildId.isEmpty else { return }
        do {
            let rows: [PlanCorrespondenceRow] = try await supabase.client
                .from("plan_correspondence")
                .select()
                .eq("build_id", value: buildId)
                .order("created_at", ascending: true)
                .execute()
                .value
            correspondence = rows.map { $0.toModel() }
        } catch {
            print("[DesignPlanVM] loadCorrespondence FAILED: \(error)")
        }
    }

    private func loadPlanDocuments() async {
        guard supabase.isConfigured, !buildId.isEmpty else { return }
        do {
            let rows: [PlanDocumentRow] = try await supabase.client
                .from("plan_documents")
                .select()
                .eq("build_id", value: buildId)
                .order("date_added", ascending: false)
                .execute()
                .value
            planDocuments = rows.filter { !$0.is_final }.map { $0.toModel() }
            finalDocuments = rows.filter { $0.is_final }.map { $0.toModel() }
        } catch {
            print("[DesignPlanVM] loadPlanDocuments FAILED: \(error)")
        }
    }

    func sendMessage() {
        guard !newMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let message = PlanCorrespondence(
            id: UUID().uuidString,
            sender: isClient ? .client : .avia,
            senderName: currentUserName,
            message: newMessageText,
            date: .now,
            attachmentName: nil
        )
        correspondence.append(message)
        newMessageText = ""

        Task { await saveCorrespondence(message) }
    }

    func submitMarkup() {
        hasUnsavedMarkup = false
        showMarkupSubmitted = true
        planStatus = .inReview

        let note = PlanCorrespondence(
            id: UUID().uuidString,
            sender: isClient ? .client : .avia,
            senderName: currentUserName,
            message: "I've submitted markup annotations on the floor plan. Please review the highlighted changes.",
            date: .now,
            attachmentName: "FloorPlan_Markup.png"
        )
        correspondence.append(note)
        Task { await saveCorrespondence(note) }
    }

    func confirmPlan() {
        clientConfirmed = true
        if aviaConfirmed {
            planStatus = .finalised
        } else {
            planStatus = .approved
        }

        let note = PlanCorrespondence(
            id: UUID().uuidString,
            sender: isClient ? .client : .avia,
            senderName: currentUserName,
            message: "I confirm approval of the current floor plan. Please proceed to finalise.",
            date: .now,
            attachmentName: nil
        )
        correspondence.append(note)
        Task { await saveCorrespondence(note) }
    }

    private func saveCorrespondence(_ item: PlanCorrespondence) async {
        guard supabase.isConfigured, !buildId.isEmpty else { return }
        let row = PlanCorrespondenceRow(from: item, buildId: buildId)
        _ = try? await supabase.client
            .from("plan_correspondence")
            .upsert(row)
            .execute()
    }
}

nonisolated struct PlanCorrespondenceRow: Codable, Sendable {
    let id: String
    let build_id: String
    let sender: String
    let sender_name: String
    let message: String
    let attachment_name: String?
    let created_at: String

    init(from item: PlanCorrespondence, buildId: String) {
        id = item.id
        build_id = buildId
        sender = item.sender.rawValue
        sender_name = item.senderName
        message = item.message
        attachment_name = item.attachmentName
        created_at = ISO8601DateFormatter().string(from: item.date)
    }

    func toModel() -> PlanCorrespondence {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        return PlanCorrespondence(
            id: id,
            sender: MessageSender(rawValue: sender) ?? .client,
            senderName: sender_name,
            message: message,
            date: formatter.date(from: created_at) ?? fallback.date(from: created_at) ?? .now,
            attachmentName: attachment_name
        )
    }
}

nonisolated struct PlanDocumentRow: Codable, Sendable {
    let id: String
    let build_id: String
    let name: String
    let type: String
    let date_added: String
    let file_size: String
    let version: String
    let is_final: Bool

    func toModel() -> PlanDocument {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        return PlanDocument(
            id: id,
            name: name,
            type: PlanDocumentType(rawValue: type) ?? .floorPlan,
            dateAdded: formatter.date(from: date_added) ?? fallback.date(from: date_added) ?? .now,
            fileSize: file_size,
            version: version,
            isFinal: is_final
        )
    }
}
