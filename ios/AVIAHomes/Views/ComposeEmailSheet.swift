import SwiftUI
import UniformTypeIdentifiers

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

    @State private var libraryDocs: [LibraryDocument] = []
    @State private var clientDocs: [ClientDocument] = []
    @State private var showAttachmentPicker: Bool = false

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
            .task { await loadAttachments() }
            .sheet(isPresented: $showAttachmentPicker) {
                AttachmentPickerSheet(
                    client: client,
                    libraryDocs: libraryDocs,
                    clientDocs: clientDocs
                ) { picked in
                    selectedDoc = picked
                    if let picked, picked.buildId == nil {
                        // Newly uploaded custom file — keep it in the client's records too.
                        clientDocs.insert(picked, at: 0)
                    }
                }
            }
        }
    }

    private func loadAttachments() async {
        async let lib = SupabaseService.shared.fetchLibraryDocuments()
        async let docs = SupabaseService.shared.fetchDocuments(clientId: client.id)
        libraryDocs = await lib
        clientDocs = await docs
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
            }
            Button {
                showAttachmentPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: selectedDoc == nil ? "paperclip" : "arrow.triangle.2.circlepath")
                        .font(.neueCaption)
                    Text(selectedDoc == nil ? "Add attachment" : "Change attachment")
                        .font(.neueCaptionMedium)
                    Spacer()
                }
                .foregroundStyle(AVIATheme.timelessBrown)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(AVIATheme.warmAccent)
                .clipShape(.rect(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            Text("Pick from the stock library, this client's files, or upload a custom file.")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
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

// MARK: - Attachment picker

/// Pick an attachment from the shared stock library, the client's own files, or by
/// uploading a custom file on the fly.
struct AttachmentPickerSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let client: ClientUser
    let libraryDocs: [LibraryDocument]
    let clientDocs: [ClientDocument]
    let onPick: (ClientDocument?) -> Void

    enum Source: String, CaseIterable { case library = "Stock library", client = "Client files" }
    @State private var source: Source = .library
    @State private var showPicker: Bool = false
    @State private var isUploading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Source", selection: $source) {
                        ForEach(Source.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    uploadButton

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.destructive)
                    }

                    if source == .library {
                        list(docs: libraryDocs.map { $0.asAttachment() }, emptyText: "No stock files yet. Ask an admin to add some to the library.")
                    } else {
                        list(docs: clientDocs, emptyText: "This client has no files yet. Upload one above.")
                    }
                }
                .padding(16)
            }
            .background(AVIATheme.background)
            .navigationTitle("Attach a file")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showPicker,
                allowedContentTypes: [.pdf, .image, .plainText, .data]
            ) { result in
                if case .success(let url) = result {
                    Task { await uploadCustom(url) }
                } else if case .failure(let error) = result {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private var uploadButton: some View {
        Button {
            showPicker = true
        } label: {
            HStack(spacing: 10) {
                if isUploading {
                    ProgressView().controlSize(.small).tint(AVIATheme.aviaWhite)
                } else {
                    Image(systemName: "arrow.up.doc.fill").font(.neueSubheadline)
                }
                Text(isUploading ? "Uploading…" : "Upload a custom file")
                    .font(.neueCaptionMedium)
                Spacer()
            }
            .foregroundStyle(AVIATheme.aviaWhite)
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(AVIATheme.primaryGradient)
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(isUploading)
    }

    private func list(docs: [ClientDocument], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if docs.isEmpty {
                Text(emptyText)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(docs) { doc in
                    Button {
                        onPick(doc)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: doc.category.icon)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.aviaWhite)
                                .frame(width: 34, height: 34)
                                .background(AVIATheme.timelessBrown)
                                .clipShape(.rect(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(doc.name)
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    Text(doc.category.rawValue)
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                    if !doc.fileSize.isEmpty {
                                        Text("·").font(.neueCaption2).foregroundStyle(AVIATheme.textTertiary)
                                        Text(doc.fileSize).font(.neueCaption2).foregroundStyle(AVIATheme.textTertiary)
                                    }
                                }
                            }
                            Spacer()
                            Image(systemName: "paperclip").font(.neueCaption).foregroundStyle(AVIATheme.timelessBrown)
                        }
                        .padding(12)
                        .background(AVIATheme.cardBackground)
                        .clipShape(.rect(cornerRadius: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func uploadCustom(_ url: URL) async {
        errorMessage = nil
        isUploading = true
        defer { isUploading = false }

        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "Couldn't read that file."
            return
        }
        let originalName = url.lastPathComponent
        let contentType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"

        guard let publicURL = await PDFUploadService.shared.uploadFile(
            data,
            fileName: originalName,
            folder: "client_\(client.id)",
            contentType: contentType
        ) else {
            errorMessage = "Upload failed. Please try again."
            return
        }
        let doc = ClientDocument(
            id: UUID().uuidString,
            name: (originalName as NSString).deletingPathExtension,
            category: .templates,
            dateAdded: .now,
            fileSize: LibraryDocumentEditorSheet.formatBytes(data.count),
            isNew: true,
            fileURL: publicURL
        )
        // Persist to the client's records so it shows in their document library too.
        await SupabaseService.shared.upsertDocument(doc, clientId: client.id)
        onPick(doc)
        dismiss()
    }
}
