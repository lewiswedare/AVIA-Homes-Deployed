import SwiftUI

struct ChatView: View {
    let conversation: Conversation
    @Environment(AppViewModel.self) private var viewModel
    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool

    private var otherUser: ClientUser? {
        let otherId = conversation.otherParticipantId(currentUserId: viewModel.currentUser.id)
        return viewModel.allRegisteredUsers.first { $0.id == otherId }
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
        .navigationTitle(otherUser?.fullName ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    Text(otherUser?.fullName ?? "Chat")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text(otherUser?.role.rawValue ?? "")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
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
    }

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(groupedMessages, id: \.0) { dateString, dayMessages in
                        dateSeparator(dateString)
                        ForEach(dayMessages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            .onAppear {
                scrollProxy = proxy
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var groupedMessages: [(String, [ChatMessage])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: messages) { msg -> String in
            if calendar.isDateInToday(msg.createdAt) {
                return "Today"
            } else if calendar.isDateInYesterday(msg.createdAt) {
                return "Yesterday"
            } else {
                return msg.createdAt.formatted(date: .abbreviated, time: .omitted)
            }
        }
        let sorted = messages.sorted { $0.createdAt < $1.createdAt }
        var result: [(String, [ChatMessage])] = []
        var currentKey = ""
        var currentGroup: [ChatMessage] = []

        for msg in sorted {
            let key: String
            if calendar.isDateInToday(msg.createdAt) {
                key = "Today"
            } else if calendar.isDateInYesterday(msg.createdAt) {
                key = "Yesterday"
            } else {
                key = msg.createdAt.formatted(date: .abbreviated, time: .omitted)
            }
            if key != currentKey {
                if !currentGroup.isEmpty {
                    result.append((currentKey, currentGroup))
                }
                currentKey = key
                currentGroup = [msg]
            } else {
                currentGroup.append(msg)
            }
        }
        if !currentGroup.isEmpty {
            result.append((currentKey, currentGroup))
        }
        return result
    }

    private func dateSeparator(_ text: String) -> some View {
        HStack {
            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 0.5)
            Text(text)
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.textTertiary)
                .fixedSize()
            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 0.5)
        }
        .padding(.vertical, 12)
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        let isMine = message.senderId == viewModel.currentUser.id
        let showTime = shouldShowTime(for: message)

        return VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
            HStack {
                if isMine { Spacer(minLength: 60) }
                Text(message.content)
                    .font(.neueSubheadline)
                    .foregroundStyle(isMine ? AVIATheme.aviaWhite : AVIATheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isMine ? AVIATheme.timelessBrown : AVIATheme.cardBackground)
                    .clipShape(.rect(cornerRadius: 18, style: .continuous))
                if !isMine { Spacer(minLength: 60) }
            }

            if showTime {
                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .padding(.horizontal, 4)
                    .padding(.top, 1)
                    .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }

    private func shouldShowTime(for message: ChatMessage) -> Bool {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return true }
        let nextIndex = messages.index(after: index)
        guard nextIndex < messages.count else { return true }
        let next = messages[nextIndex]
        if next.senderId != message.senderId { return true }
        return next.createdAt.timeIntervalSince(message.createdAt) > 300
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Message", text: $messageText, axis: .vertical)
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textPrimary)
                .tint(AVIATheme.timelessBrown)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AVIATheme.cardBackground)
                .clipShape(.rect(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                }
                .focused($isInputFocused)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AVIATheme.surfaceBorder : AVIATheme.timelessBrown)
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .sensoryFeedback(.impact(weight: .light), trigger: messages.count)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

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

            let recipientId = conversation.otherParticipantId(currentUserId: viewModel.currentUser.id)
            await viewModel.notificationService.createNotification(
                recipientId: recipientId,
                senderId: viewModel.currentUser.id,
                senderName: viewModel.currentUser.fullName,
                type: .newMessage,
                title: "New Message",
                message: "\(viewModel.currentUser.fullName): \(text.prefix(100))",
                referenceId: conversation.id,
                referenceType: "conversation"
            )

            scrollToBottom()
        }
    }

    private func scrollToBottom() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(duration: 0.25)) {
                scrollProxy?.scrollTo("bottom", anchor: .bottom)
            }
        }
    }
}
