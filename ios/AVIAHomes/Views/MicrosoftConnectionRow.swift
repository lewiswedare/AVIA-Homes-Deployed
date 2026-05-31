import SwiftUI

/// Profile row that lets a staff member connect / disconnect their Microsoft 365
/// account so emails sent from the app go out from their real Outlook mailbox.
struct MicrosoftConnectionRow: View {
    @Environment(AppViewModel.self) private var viewModel

    @State private var account: MicrosoftAccount?
    @State private var isLoading: Bool = true
    @State private var isWorking: Bool = false
    @State private var showDisconnectAlert: Bool = false
    @State private var errorMessage: String?

    private let mail = MicrosoftMailService.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.neueSubheadline)
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Microsoft 365")
                        .font(.neueSubheadline)
                        .foregroundStyle(AVIATheme.textPrimary)
                    if isLoading {
                        Text("Checking connection…")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                    } else if let email = account?.email, !(email.isEmpty) {
                        HStack(spacing: 5) {
                            Circle().fill(AVIATheme.success).frame(width: 6, height: 6)
                            Text("Sending as \(email)")
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                                .lineLimit(1)
                        }
                    } else {
                        Text("Send emails from your real Outlook account")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()

                if isWorking {
                    ProgressView()
                } else if account != nil {
                    Button("Disconnect", role: .destructive) {
                        showDisconnectAlert = true
                    }
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.destructive)
                } else if !isLoading {
                    Button {
                        Task { await connect() }
                    } label: {
                        Text("Connect")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(AVIATheme.timelessBrown)
                            .clipShape(.capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if let errorMessage {
                Text(errorMessage)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.destructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
        .task { await refresh() }
        .alert("Disconnect Microsoft?", isPresented: $showDisconnectAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Disconnect", role: .destructive) {
                Task { await disconnect() }
            }
        } message: {
            Text("You'll need to reconnect before sending emails from the app again.")
        }
    }

    private func refresh() async {
        isLoading = true
        account = await mail.fetchStatus(staffId: viewModel.currentUser.id)
        isLoading = false
    }

    private func connect() async {
        errorMessage = nil
        isWorking = true
        let success = await mail.connect(staffId: viewModel.currentUser.id)
        if success {
            // Give the backend a beat to persist, then refresh status.
            try? await Task.sleep(for: .milliseconds(600))
            account = await mail.fetchStatus(staffId: viewModel.currentUser.id)
            if account == nil {
                errorMessage = "Connected, but we couldn't confirm it. Pull to refresh."
            }
        } else {
            errorMessage = "Microsoft connection was cancelled or failed."
        }
        isWorking = false
    }

    private func disconnect() async {
        isWorking = true
        let ok = await mail.disconnect(staffId: viewModel.currentUser.id)
        if ok { account = nil } else { errorMessage = "Couldn't disconnect. Try again." }
        isWorking = false
    }
}
