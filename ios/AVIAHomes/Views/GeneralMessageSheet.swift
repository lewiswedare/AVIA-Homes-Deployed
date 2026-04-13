import SwiftUI

struct GeneralMessageSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var navigateToChat = false
    @State private var conversation: Conversation?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "message.fill")
                .font(.system(size: 48))
                .foregroundStyle(AVIATheme.teal)
            Text("General Message")
                .font(.neueCorpMedium(22))
                .foregroundStyle(AVIATheme.textPrimary)
            Text("Send a message to the AVIA Homes team. An admin will respond to you.")
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            PremiumButton("Start Conversation", icon: "bubble.left.fill", style: .primary) {
                Task { await openGeneralConversation() }
            }
            .disabled(isLoading)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(AVIATheme.background)
        .navigationTitle("General Message")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .font(.neueSubheadline)
            }
        }
        .navigationDestination(isPresented: $navigateToChat) {
            if let conv = conversation {
                ChatView(conversation: conv)
            }
        }
    }

    private func openGeneralConversation() async {
        isLoading = true
        defer { isLoading = false }
        let convId = await viewModel.messagingService.getOrCreateGeneralConversation(currentUserId: viewModel.currentUser.id)
        if let conv = viewModel.messagingService.conversations.first(where: { $0.id == convId }) {
            conversation = conv
            navigateToChat = true
        }
    }
}
