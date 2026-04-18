import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ChatView: View {
    let conversation: Conversation
    @Environment(AppViewModel.self) private var viewModel
    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool

    @State private var showAttachMenu = false
    @State private var photoItem: PhotosPickerItem?
    @State private var showPhotosPicker = false
    @State private var showFileImporter = false
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    @State private var isUploading = false
    @State private var fullScreenImage: ChatImagePreview?
    @State private var uploadError: String?

    private var otherUser: ClientUser? {
        let otherId = conversation.otherParticipantId(currentUserId: viewModel.currentUser.id)
        return viewModel.allRegisteredUsers.first { $0.id == otherId }
    }

    private var headerTitle: String {
        conversation.isGeneral ? "AVIA Homes" : (otherUser?.fullName ?? "Chat")
    }

    private var messages: [ChatMessage] {
        viewModel.messagingService.currentMessages
    }

    var body: some View {
        VStack(spacing: 0) {
            messagesScrollView
            inputBar
        }
        .background(AVIATheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                headerView
            }
        }
        .task {
            await viewModel.messagingService.loadMessages(for: conversation.id)
            await viewModel.messagingService.markConversationRead(
                conversationId: conversation.id,
                userId: viewModel.currentUser.id
            )
            viewModel.messagingService.subscribeToMessages(conversationId: conversation.id)
        }
        .onChange(of: messages.count) { _, _ in
            scrollToBottom()
        }
        .onChange(of: photoItem) { _, newItem in
            if let newItem {
                Task { await handlePhotoPick(newItem) }
            }
        }
        .onChange(of: cameraImage) { _, newImage in
            if let newImage {
                Task { await handleCameraImage(newImage) }
            }
        }
        .confirmationDialog("Attach", isPresented: $showAttachMenu, titleVisibility: .hidden) {
            Button("Take Photo") { showCamera = true }
            Button("Photo Library") { showPhotosPicker = true }
            Button("Choose File") { showFileImporter = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $photoItem, matching: .images)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .image, .plainText, .text, .rtf, .presentation, .spreadsheet, .item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task { await handleFilePick(url: url) }
                }
            case .failure(let error):
                uploadError = error.localizedDescription
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerRepresentable(image: $cameraImage)
                .ignoresSafeArea()
        }
        .fullScreenCover(item: $fullScreenImage) { item in
            ChatImageViewer(urlString: item.urlString)
        }
        .alert("Upload Failed", isPresented: Binding(
            get: { uploadError != nil },
            set: { if !$0 { uploadError = nil } }
        )) {
            Button("OK", role: .cancel) { uploadError = nil }
        } message: {
            Text(uploadError ?? "")
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 4) {
            headerAvatar
            Text(headerTitle)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textPrimary)
                .lineLimit(1)
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var headerAvatar: some View {
        if conversation.isGeneral {
            Text("A")
                .font(.neueCorpMedium(14))
                .foregroundStyle(AVIATheme.aviaWhite)
                .frame(width: 32, height: 32)
                .background(AVIATheme.primaryGradient)
                .clipShape(Circle())
        } else {
            UserAvatarView(
                avatarUrl: otherUser?.avatarUrl,
                initials: otherUser?.initials ?? "?",
                size: 32
            )
        }
    }

    // MARK: - Scroll / messages

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        if shouldShowDateSeparator(at: index) {
                            dateSeparator(dateSeparatorText(for: message.createdAt))
                                .padding(.top, index == 0 ? 4 : 16)
                                .padding(.bottom, 4)
                        }
                        messageRow(message, at: index)
                            .id(message.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                scrollProxy = proxy
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let previous = messages[index - 1].createdAt
        let current = messages[index].createdAt
        return current.timeIntervalSince(previous) > 60 * 60
    }

    private func dateSeparatorText(for date: Date) -> String {
        let calendar = Calendar.current
        let timeString = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) {
            return timeString
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday \(timeString)"
        } else if let days = calendar.dateComponents([.day], from: date, to: .now).day, days < 7 {
            let weekday = date.formatted(.dateTime.weekday(.wide))
            return "\(weekday) \(timeString)"
        } else {
            return date.formatted(.dateTime.day().month().year().hour().minute())
        }
    }

    private func dateSeparator(_ text: String) -> some View {
        Text(text)
            .font(.neueCaption2Medium)
            .foregroundStyle(AVIATheme.textTertiary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }

    // MARK: - Rows

    @ViewBuilder
    private func messageRow(_ message: ChatMessage, at index: Int) -> some View {
        let isMine = message.senderId == viewModel.currentUser.id
        let isLastInCluster = isLastInCluster(at: index)
        let showAvatar = !isMine && isLastInCluster
        let showTail = isLastInCluster

        HStack(alignment: .bottom, spacing: 6) {
            if !isMine {
                if showAvatar {
                    senderAvatar(for: message)
                } else {
                    Color.clear.frame(width: 28, height: 28)
                }
            } else {
                Spacer(minLength: 60)
            }

            bubble(for: message, isMine: isMine, showTail: showTail)

            if !isMine {
                Spacer(minLength: 60)
            }
        }
        .padding(.top, isFirstInCluster(at: index) ? 6 : 1)
    }

    @ViewBuilder
    private func senderAvatar(for message: ChatMessage) -> some View {
        if conversation.isGeneral && message.senderId != viewModel.currentUser.id {
            // General conversation: sender may be any admin/staff
            if let sender = viewModel.allRegisteredUsers.first(where: { $0.id == message.senderId }) {
                UserAvatarView(user: sender, size: 28)
            } else {
                Text("A")
                    .font(.neueCorpMedium(12))
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 28, height: 28)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(Circle())
            }
        } else {
            UserAvatarView(
                avatarUrl: otherUser?.avatarUrl,
                initials: otherUser?.initials ?? "?",
                size: 28
            )
        }
    }

    private func isFirstInCluster(at index: Int) -> Bool {
        guard index > 0 else { return true }
        let prev = messages[index - 1]
        let curr = messages[index]
        if prev.senderId != curr.senderId { return true }
        if curr.createdAt.timeIntervalSince(prev.createdAt) > 120 { return true }
        return false
    }

    private func isLastInCluster(at index: Int) -> Bool {
        let next = index + 1
        guard next < messages.count else { return true }
        let curr = messages[index]
        let nxt = messages[next]
        if nxt.senderId != curr.senderId { return true }
        if nxt.createdAt.timeIntervalSince(curr.createdAt) > 120 { return true }
        return false
    }

    // MARK: - Bubble

    @ViewBuilder
    private func bubble(for message: ChatMessage, isMine: Bool, showTail: Bool) -> some View {
        let bubbleColor: Color = isMine ? AVIATheme.timelessBrown : AVIATheme.cardBackground
        let textColor: Color = isMine ? AVIATheme.aviaWhite : AVIATheme.textPrimary

        VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
            if message.hasImageAttachment, let urlString = message.attachmentUrl, let url = URL(string: urlString) {
                Button {
                    fullScreenImage = ChatImagePreview(urlString: urlString)
                } label: {
                    Color(.secondarySystemBackground)
                        .frame(width: 240, height: 240)
                        .overlay {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .allowsHitTesting(false)
                                case .empty:
                                    ProgressView().tint(AVIATheme.textSecondary)
                                default:
                                    Image(systemName: "photo")
                                        .font(.system(size: 32))
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }
                            }
                        }
                        .clipShape(iMessageBubbleShape(isMine: isMine, hasTail: showTail && message.content.isEmpty))
                }
                .buttonStyle(.plain)
            }

            if !message.content.isEmpty {
                Text(message.content)
                    .font(.neueSubheadline)
                    .foregroundStyle(textColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(bubbleColor)
                    .clipShape(iMessageBubbleShape(isMine: isMine, hasTail: showTail))
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            attachmentButton

            HStack(alignment: .bottom, spacing: 8) {
                TextField("iMessage", text: $messageText, axis: .vertical)
                    .font(.neueSubheadline)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .tint(AVIATheme.timelessBrown)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .focused($isInputFocused)

                if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .frame(width: 28, height: 28)
                            .background(AVIATheme.timelessBrown)
                            .clipShape(Circle())
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: messages.count)
                    .padding(.trailing, 4)
                    .padding(.bottom, 4)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .background(
                Capsule(style: .continuous)
                    .fill(AVIATheme.cardBackground)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(AVIATheme.surfaceBorder, lineWidth: 0.5)
            )
        }
        .animation(.spring(duration: 0.25), value: messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AVIATheme.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AVIATheme.surfaceBorder.opacity(0.6))
                .frame(height: 0.5)
        }
    }

    @ViewBuilder
    private var attachmentButton: some View {
        Button {
            showAttachMenu = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(AVIATheme.timelessBrown)
                .frame(width: 32, height: 32)
                .background(AVIATheme.cardBackground)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 0.5)
                )
        }
        .disabled(isUploading)
        .overlay {
            if isUploading {
                ProgressView()
                    .tint(AVIATheme.timelessBrown)
                    .scaleEffect(0.7)
            }
        }
        .padding(.bottom, 2)
    }

    // MARK: - Sending

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""

        Task {
            await viewModel.messagingService.sendMessage(
                conversationId: conversation.id,
                senderId: viewModel.currentUser.id,
                content: text
            )
            await notifyRecipient(preview: text)
            scrollToBottom()
        }
    }

    private func handlePhotoPick(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = await ImageUploadService.shared.loadTransferable(from: item) else { return }
        await uploadAndSend(data: data)
    }

    private func handleCameraImage(_ image: UIImage) async {
        defer { cameraImage = nil }
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        await uploadAndSend(data: data)
    }

    private func handleFilePick(url: URL) async {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            uploadError = "Couldn't read the selected file."
            return
        }
        let fileName = url.lastPathComponent
        let mimeType = mimeType(for: url.pathExtension)
        await uploadAndSendFile(data: data, fileName: fileName, mimeType: mimeType)
    }

    private func uploadAndSendFile(data: Data, fileName: String, mimeType: String) async {
        isUploading = true
        defer { isUploading = false }
        let safeName = fileName.replacingOccurrences(of: " ", with: "_")
        let storageName = "\(conversation.id)_\(UUID().uuidString)_\(safeName)"
        guard let url = await ImageUploadService.shared.uploadFile(
            data,
            folder: "messages",
            fileName: storageName,
            contentType: mimeType
        ) else {
            uploadError = "Upload failed. Please try again."
            return
        }
        let isImage = mimeType.hasPrefix("image")
        await viewModel.messagingService.sendMessage(
            conversationId: conversation.id,
            senderId: viewModel.currentUser.id,
            content: isImage ? "" : fileName,
            attachmentUrl: url,
            attachmentType: mimeType
        )
        await notifyRecipient(preview: isImage ? "\u{1F4F7} Photo" : "\u{1F4CE} \(fileName)")
        scrollToBottom()
    }

    private func mimeType(for ext: String) -> String {
        if let type = UTType(filenameExtension: ext.lowercased()), let mime = type.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }

    private func uploadAndSend(data: Data) async {
        isUploading = true
        defer { isUploading = false }
        let fileName = "\(conversation.id)_\(UUID().uuidString).jpg"
        guard let url = await ImageUploadService.shared.uploadFile(
            data,
            folder: "messages",
            fileName: fileName,
            contentType: "image/jpeg"
        ) else {
            uploadError = "Upload failed. Please try again."
            return
        }
        await viewModel.messagingService.sendMessage(
            conversationId: conversation.id,
            senderId: viewModel.currentUser.id,
            content: "",
            attachmentUrl: url,
            attachmentType: "image/jpeg"
        )
        await notifyRecipient(preview: "\u{1F4F7} Photo")
        scrollToBottom()
    }

    private func notifyRecipient(preview: String) async {
        let recipientId = conversation.otherParticipantId(currentUserId: viewModel.currentUser.id)
        guard !recipientId.isEmpty else { return }
        await viewModel.notificationService.createNotification(
            recipientId: recipientId,
            senderId: viewModel.currentUser.id,
            senderName: viewModel.currentUser.fullName,
            type: .newMessage,
            title: "New Message",
            message: "\(viewModel.currentUser.fullName): \(preview.prefix(100))",
            referenceId: conversation.id,
            referenceType: "conversation"
        )
    }

    private func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(duration: 0.25)) {
                scrollProxy?.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}

// MARK: - iMessage-style bubble shape

private struct iMessageBubbleShape: Shape {
    let isMine: Bool
    let hasTail: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        if !hasTail {
            return Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
        }

        var path = Path()
        let w = rect.width
        let h = rect.height
        let r = min(radius, min(w, h) / 2)
        let tail: CGFloat = 6

        if isMine {
            path.move(to: CGPoint(x: r, y: 0))
            path.addLine(to: CGPoint(x: w - r, y: 0))
            path.addQuadCurve(to: CGPoint(x: w, y: r), control: CGPoint(x: w, y: 0))
            path.addLine(to: CGPoint(x: w, y: h - r))
            path.addQuadCurve(to: CGPoint(x: w - tail, y: h), control: CGPoint(x: w, y: h))
            path.addLine(to: CGPoint(x: r, y: h))
            path.addQuadCurve(to: CGPoint(x: 0, y: h - r), control: CGPoint(x: 0, y: h))
            path.addLine(to: CGPoint(x: 0, y: r))
            path.addQuadCurve(to: CGPoint(x: r, y: 0), control: CGPoint(x: 0, y: 0))
        } else {
            path.move(to: CGPoint(x: r, y: 0))
            path.addLine(to: CGPoint(x: w - r, y: 0))
            path.addQuadCurve(to: CGPoint(x: w, y: r), control: CGPoint(x: w, y: 0))
            path.addLine(to: CGPoint(x: w, y: h - r))
            path.addQuadCurve(to: CGPoint(x: w - r, y: h), control: CGPoint(x: w, y: h))
            path.addLine(to: CGPoint(x: tail, y: h))
            path.addQuadCurve(to: CGPoint(x: 0, y: h - r), control: CGPoint(x: 0, y: h))
            path.addLine(to: CGPoint(x: 0, y: r))
            path.addQuadCurve(to: CGPoint(x: r, y: 0), control: CGPoint(x: 0, y: 0))
        }

        path.closeSubpath()
        return path
    }
}

private struct ChatImagePreview: Identifiable {
    let urlString: String
    var id: String { urlString }
}

private struct ChatImageViewer: View {
    let urlString: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .empty:
                            ProgressView().tint(.white)
                        default:
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.white)
                        }
                    }
                    .padding()
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(.white)
                }
            }
        }
    }
}
