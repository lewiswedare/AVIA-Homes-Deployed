import SwiftUI

/// CRM section: browse the client's document library, compose & send email from the
/// staff member's real Microsoft 365 account, and review what's been sent / opened.
struct ClientDocumentsSendingSection: View {
    @Environment(AppViewModel.self) private var viewModel
    let client: ClientUser

    @State private var documents: [ClientDocument] = []
    @State private var libraryDocs: [LibraryDocument] = []
    @State private var sends: [EmailSend] = []
    @State private var msAccount: MicrosoftAccount?
    @State private var isLoading: Bool = true

    @State private var composeAttachment: ClientDocument?
    @State private var showCompose: Bool = false
    @State private var prefill: ComposePrefill = .blank

    private var isConnected: Bool { msAccount != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if !isConnected && !isLoading {
                connectPrompt
            }
            composeButton
            if !libraryDocs.isEmpty {
                stockLibrary
            }
            if !documents.isEmpty {
                documentLibrary
            }
            sentHistory
        }
        .task { await load() }
        .sheet(isPresented: $showCompose) {
            ComposeEmailSheet(
                client: client,
                senderName: viewModel.currentUser.fullName,
                attachment: composeAttachment,
                prefill: prefill,
                isConnected: isConnected
            ) {
                await refreshSends()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("DOCUMENTS & SENDING")
                .font(.neueCaption2Medium)
                .tracking(1.2)
                .foregroundStyle(AVIATheme.textTertiary)
            Spacer()
            if isLoading {
                ProgressView().scaleEffect(0.7)
            }
        }
    }

    private var connectPrompt: some View {
        BentoCard(cornerRadius: 12) {
            HStack(spacing: 10) {
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.neueTitle3)
                    .foregroundStyle(AVIATheme.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect Microsoft to send")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Link your Outlook account in Profile to send from your own address.")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Compose

    private var composeButton: some View {
        VStack(spacing: 8) {
            Button {
                composeAttachment = nil
                prefill = .blank
                showCompose = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.neueSubheadlineMedium)
                    Text("Compose email")
                        .font(.neueCaptionMedium)
                    Spacer()
                    Image(systemName: "paperplane.fill")
                        .font(.neueCaption)
                }
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity)
                .background(AVIATheme.primaryGradient)
                .clipShape(.rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                ForEach(ComposePrefill.quickActions) { action in
                    Button {
                        composeAttachment = action.preferredDocument(in: documents)
                        prefill = action
                        showCompose = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: action.icon)
                                .font(.neueCaption2)
                            Text(action.chipLabel)
                                .font(.neueCaption2Medium)
                        }
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AVIATheme.warmAccent)
                        .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Stock library

    private var stockLibrary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "books.vertical.fill")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.timelessBrown)
                Text("Stock library")
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            VStack(spacing: 6) {
                ForEach(libraryDocs) { doc in
                    Button {
                        let attachment = doc.asAttachment()
                        composeAttachment = attachment
                        prefill = .document(attachment)
                        showCompose = true
                    } label: {
                        documentRow(doc.asAttachment())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Client document library

    private var documentLibrary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Client files")
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.textSecondary)
            VStack(spacing: 6) {
                ForEach(documents) { doc in
                    Button {
                        composeAttachment = doc
                        prefill = .document(doc)
                        showCompose = true
                    } label: {
                        documentRow(doc)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func documentRow(_ doc: ClientDocument) -> some View {
        BentoCard(cornerRadius: 11) {
            HStack(spacing: 12) {
                Image(systemName: doc.category.icon)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 32, height: 32)
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
                        Text("·").font(.neueCaption2).foregroundStyle(AVIATheme.textTertiary)
                        Text(doc.fileSize)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }
                Spacer()
                Image(systemName: "paperclip")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.timelessBrown)
            }
            .padding(12)
        }
    }

    // MARK: - Sent history

    private var sentHistory: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sent history")
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.textSecondary)
            if sends.isEmpty {
                BentoCard(cornerRadius: 12) {
                    Text("Nothing sent yet. Compose an email above — you'll see delivery and open status here.")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(sends) { send in
                        EmailSendRowView(send: send)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: sends)
            }
        }
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        async let docs = SupabaseService.shared.fetchDocuments(clientId: client.id)
        async let lib = SupabaseService.shared.fetchLibraryDocuments()
        async let sendsList = SupabaseService.shared.fetchEmailSends(clientId: client.id)
        async let account = MicrosoftMailService.shared.fetchStatus(staffId: viewModel.currentUser.id)
        documents = await docs
        libraryDocs = await lib
        sends = await sendsList
        msAccount = await account
        isLoading = false
    }

    private func refreshSends() async {
        sends = await SupabaseService.shared.fetchEmailSends(clientId: client.id)
    }
}

// MARK: - Sent row

struct EmailSendRowView: View {
    let send: EmailSend

    var body: some View {
        BentoCard(cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(send.subject)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    statusPill
                }
                if let preview = send.bodyPreview, !preview.isEmpty {
                    Text(preview)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    if let name = send.documentName, !name.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "paperclip").font(.neueCaption2)
                            Text(name).font(.neueCaption2).lineLimit(1)
                        }
                        .foregroundStyle(AVIATheme.timelessBrown)
                    }
                    Spacer()
                    Text(metaText)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }
            .padding(12)
        }
    }

    private var metaText: String {
        let sender = send.senderName?.isEmpty == false ? send.senderName! : (send.senderEmail ?? "You")
        return "\(sender) · \(send.createdAt.formatted(.relative(presentation: .named)))"
    }

    @ViewBuilder
    private var statusPill: some View {
        if send.didFail {
            pill(text: "Failed", icon: "exclamationmark.triangle.fill", color: AVIATheme.destructive)
        } else if send.isOpened {
            pill(
                text: send.openCount > 1 ? "Opened \(send.openCount)×" : "Opened",
                icon: "envelope.open.fill",
                color: AVIATheme.success
            )
        } else {
            pill(text: "Sent", icon: "checkmark", color: AVIATheme.textTertiary)
        }
    }

    private func pill(text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold))
            Text(text).font(.neueCaption2Medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color.opacity(0.14))
        .clipShape(.capsule)
    }
}

// MARK: - Compose prefill presets

enum ComposePrefill: Identifiable {
    case blank
    case sendPlans
    case sendContract
    case followUp
    case document(ClientDocument)

    var id: String {
        switch self {
        case .blank: return "blank"
        case .sendPlans: return "plans"
        case .sendContract: return "contract"
        case .followUp: return "followup"
        case .document(let d): return "doc-\(d.id)"
        }
    }

    static var quickActions: [ComposePrefill] { [.sendPlans, .sendContract, .followUp] }

    var icon: String {
        switch self {
        case .sendPlans: return "ruler.fill"
        case .sendContract: return "doc.text.fill"
        case .followUp: return "arrow.uturn.right"
        default: return "square.and.pencil"
        }
    }

    var chipLabel: String {
        switch self {
        case .sendPlans: return "Send plans"
        case .sendContract: return "Send contract"
        case .followUp: return "Follow up"
        default: return "Compose"
        }
    }

    func subject(clientName: String) -> String {
        switch self {
        case .sendPlans: return "Your AVIA Homes plans"
        case .sendContract: return "Your AVIA Homes contract"
        case .followUp: return "Following up — AVIA Homes"
        case .document(let d): return d.name
        case .blank: return ""
        }
    }

    func body(clientName: String, senderName: String) -> String {
        let hi = clientName.isEmpty ? "Hi," : "Hi \(clientName.components(separatedBy: " ").first ?? clientName),"
        let signoff = "\n\nKind regards,\n\(senderName)\nAVIA Homes"
        switch self {
        case .sendPlans:
            return "\(hi)\n\nPlease find your plans attached. Let me know if you'd like to talk anything through.\(signoff)"
        case .sendContract:
            return "\(hi)\n\nPlease find your contract attached for review. Happy to walk you through any of it.\(signoff)"
        case .followUp:
            return "\(hi)\n\nJust following up on our recent conversation — let me know if there's anything I can help with.\(signoff)"
        case .document(let d):
            return "\(hi)\n\nPlease find \(d.name) attached.\(signoff)"
        case .blank:
            return "\(hi)\n\(signoff)"
        }
    }

    /// Best matching document in the library for a quick action (e.g. a Plans doc).
    func preferredDocument(in docs: [ClientDocument]) -> ClientDocument? {
        switch self {
        case .sendPlans: return docs.first { $0.category == .plans }
        case .sendContract: return docs.first { $0.category == .contracts }
        case .document(let d): return d
        default: return nil
        }
    }
}
