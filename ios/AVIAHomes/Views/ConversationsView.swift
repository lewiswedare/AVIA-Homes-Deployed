import SwiftUI

struct ConversationsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedConversation: Conversation?
    @State private var showNewMessage = false

    private var sortedConversations: [Conversation] {
        viewModel.messagingService.conversations.sorted { $0.lastMessageDate > $1.lastMessageDate }
    }

    var body: some View {
        ScrollView {
            if sortedConversations.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(sortedConversations) { conversation in
                        NavigationLink(value: conversation) {
                            conversationRow(conversation)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .background(AVIATheme.background)
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewMessage = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.neueSubheadline)
                }
                .tint(AVIATheme.teal)
            }
        }
        .navigationDestination(for: Conversation.self) { conversation in
            ChatView(conversation: conversation)
        }
        .sheet(isPresented: $showNewMessage) {
            NewConversationSheet()
        }
        .refreshable {
            await viewModel.messagingService.loadConversations(for: viewModel.currentUser.id)
        }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        let otherUserId = conversation.otherParticipantId(currentUserId: viewModel.currentUser.id)
        let otherUser = viewModel.allRegisteredUsers.first { $0.id == otherUserId }
        let hasUnread = conversation.unreadCount > 0 && conversation.lastSenderId != viewModel.currentUser.id

        return HStack(spacing: 14) {
            Text(otherUser?.initials ?? "?")
                .font(.neueCorpMedium(14))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(AVIATheme.tealGradient)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(otherUser?.fullName ?? "Unknown User")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    Text(formatDate(conversation.lastMessageDate))
                        .font(.neueCaption2)
                        .foregroundStyle(hasUnread ? AVIATheme.teal : AVIATheme.textTertiary)
                }

                HStack(spacing: 6) {
                    if conversation.lastSenderId == viewModel.currentUser.id && !conversation.lastMessage.isEmpty {
                        Text("You:")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    Text(conversation.lastMessage.isEmpty ? "No messages yet" : conversation.lastMessage)
                        .font(.neueCaption)
                        .foregroundStyle(hasUnread ? AVIATheme.textPrimary : AVIATheme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    if hasUnread {
                        Text("\(conversation.unreadCount)")
                            .font(.neueCorpMedium(10))
                            .foregroundStyle(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(AVIATheme.teal)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(hasUnread ? AVIATheme.teal.opacity(0.03) : Color.clear)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "message")
                .font(.system(size: 44))
                .foregroundStyle(AVIATheme.textTertiary)
            Text("No Messages")
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.textPrimary)
            Text("Start a conversation with your\nbuild team or clients.")
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                showNewMessage = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.message.fill")
                    Text("New Message")
                }
                .font(.neueSubheadlineMedium)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(AVIATheme.tealGradient)
                .clipShape(.rect(cornerRadius: 14))
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

struct NewConversationSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var availableUsers: [ClientUser] {
        let currentId = viewModel.currentUser.id
        var users: [ClientUser] = []

        switch viewModel.currentRole {
        case .client:
            if let staffId = viewModel.currentUser.assignedStaffId {
                users = viewModel.allRegisteredUsers.filter { $0.id == staffId }
            }
            if let partnerId = viewModel.currentUser.salesPartnerId {
                users += viewModel.allRegisteredUsers.filter { $0.id == partnerId }
            }
        case .staff:
            let clientIds = viewModel.currentUser.assignedClientIds
            users = viewModel.allRegisteredUsers.filter { clientIds.contains($0.id) || $0.role == .admin }
        case .partner, .salesPartner:
            let sharedClientIds = viewModel.packageAssignments
                .filter { $0.assignedPartnerIds.contains(currentId) }
                .flatMap(\.sharedWithClientIds)
            users = viewModel.allRegisteredUsers.filter { sharedClientIds.contains($0.id) }
        case .admin, .salesAdmin:
            users = viewModel.allRegisteredUsers
        default:
            users = []
        }

        users = users.filter { $0.id != currentId }

        if !searchText.isEmpty {
            users = users.filter {
                $0.fullName.localizedStandardContains(searchText) ||
                $0.email.localizedStandardContains(searchText)
            }
        }

        return users
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(availableUsers, id: \.id) { user in
                    Button {
                        Task {
                            let _ = await viewModel.messagingService.getOrCreateConversation(
                                currentUserId: viewModel.currentUser.id,
                                otherUserId: user.id
                            )
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Text(user.initials.isEmpty ? "?" : user.initials)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(AVIATheme.tealGradient)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.fullName)
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text(user.role.rawValue)
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search people")
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(AVIATheme.teal)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AVIATheme.background)
    }
}
