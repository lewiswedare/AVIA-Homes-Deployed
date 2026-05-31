import SwiftUI

/// Compose & send an email to a client from the staff member's Microsoft 365 account.
struct ComposeEmailSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let client: ClientUser
    let senderName: String
    let attachment: ClientDocument?
    let prefill: ComposePrefill
    let isConnected: Bool
    let onSent: () async -> Void

    @State private var subject: String = ""
    @State private var messageBody: String = ""
    @State private var selectedDoc: ClientDocument?
    @State private var isSending: Bool = false
    @State private var errorMessage: String?

    private var canSend: Bool {
        isConnected
        && !subject.trimmingCharacters(in: .whitespaces).isEmpty
        && !messageBody.trimmingCharacters(in: .whitespaces).isEmpty
        && !client.email.isEmpty
        && !isSending
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    recipientRow
                    fieldCard(title: "Subject") {
                        TextField("Subject", text: $subject)
                            .font(.neueSubheadline)
                    }
                    fieldCard(title: "Message") {
                        TextField("Write your message…", text: $messageBody, axis: .vertical)
                            .font(.neueSubheadline)
                            .lineLimit(8...20)
                    }
                    attachmentCard
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.destructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    sendButton
                }
                .padding(16)
            }
            .background(AVIATheme.background)
            .navigationTitle("New Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: applyPrefill)
        }
    }

    private var recipientRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TO")
                .font(.neueCaption2Medium)
                .tracking(1.0)
                .foregroundStyle(AVIATheme.textTertiary)
            HStack(spacing: 8) {
                Text(client.initials.isEmpty ? "?" : client.initials)
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 26, height: 26)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text(client.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? client.email : client.fullName)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text(client.email)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                Spacer()
            }
            .padding(10)
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 10))
        }
    }

    private func fieldCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.neueCaption2Medium)
                .tracking(1.0)
                .foregroundStyle(AVIATheme.textTertiary)
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AVIATheme.cardBackground)
                .clipShape(.rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10).stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                }
        }
    }

    private var attachmentCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ATTACHMENT")
                .font(.neueCaption2Medium)
                .tracking(1.0)
                .foregroundStyle(AVIATheme.textTertiary)
            if let doc = selectedDoc {
                HStack(spacing: 12) {
                    Image(systemName: doc.category.icon)
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(width: 30, height: 30)
                        .background(AVIATheme.timelessBrown)
                        .clipShape(.rect(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(doc.name)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                            .lineLimit(1)
                        Text(doc.fileSize)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    Spacer()
                    Button {
                        selectedDoc = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.neueSubheadline)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(AVIATheme.cardBackground)
                .clipShape(.rect(cornerRadius: 10))
            } else {
                Text("No document attached. Pick one from the library before composing to attach it.")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .padding(.vertical, 4)
            }
        }
    }

    private var sendButton: some View {
        Button {
            Task { await send() }
        } label: {
            HStack(spacing: 8) {
                if isSending {
                    ProgressView().tint(AVIATheme.aviaWhite)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.neueSubheadlineMedium)
                }
                Text(isConnected ? "Send from \(firstName(senderName))" : "Connect Microsoft to send")
                    .font(.neueSubheadlineMedium)
            }
            .foregroundStyle(AVIATheme.aviaWhite)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(canSend ? AnyShapeStyle(AVIATheme.primaryGradient) : AnyShapeStyle(AVIATheme.textTertiary.opacity(0.5)))
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
    }

    private func firstName(_ name: String) -> String {
        name.components(separatedBy: " ").first ?? name
    }

    private func applyPrefill() {
        if subject.isEmpty { subject = prefill.subject(clientName: client.fullName) }
        if messageBody.isEmpty { messageBody = prefill.body(clientName: client.fullName, senderName: senderName) }
        if selectedDoc == nil { selectedDoc = attachment }
    }

    private func send() async {
        errorMessage = nil
        isSending = true
        let result = await MicrosoftMailService.shared.sendEmail(
            staffId: viewModel.currentUser.id,
            clientId: client.id,
            to: client.email,
            subject: subject.trimmingCharacters(in: .whitespaces),
            body: messageBody,
            documentURL: selectedDoc?.fileURL,
            documentName: selectedDoc?.name,
            documentId: selectedDoc?.id
        )
        if result.success {
            await logCommunication()
            await onSent()
            isSending = false
            dismiss()
        } else {
            errorMessage = result.message ?? "Couldn't send the email."
            isSending = false
        }
    }

    private func logCommunication() async {
        var summary = "Emailed: \(subject.trimmingCharacters(in: .whitespaces))"
        if let name = selectedDoc?.name { summary += " (attached \(name))" }
        let comm = ClientCommunication(
            id: UUID().uuidString,
            clientId: client.id,
            authorId: viewModel.currentUser.id,
            kind: .email,
            summary: summary,
            occurredAt: .now,
            createdAt: .now
        )
        await SupabaseService.shared.upsertClientCommunication(comm)
    }
}
