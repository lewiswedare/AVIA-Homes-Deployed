import SwiftUI

struct PendingApprovalView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var showSignOutAlert = false
    @State private var animatePulse = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                ZStack {
                    Circle()
                        .fill(AVIATheme.teal.opacity(0.08))
                        .frame(width: 140, height: 140)
                        .scaleEffect(animatePulse ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: animatePulse)

                    Circle()
                        .fill(AVIATheme.teal.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(AVIATheme.teal)
                }

                VStack(spacing: 10) {
                    Text("Account Under Review")
                        .font(.neueCorpMedium(24))
                        .foregroundStyle(AVIATheme.textPrimary)

                    Text("Your account has been created successfully. An AVIA Homes administrator will set up your access shortly.")
                        .font(.neueSubheadline)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                BentoCard(cornerRadius: 16) {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AVIATheme.success)
                            Text("Account created")
                                .font(.neueSubheadline)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Spacer()
                        }

                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AVIATheme.success)
                            Text("Profile completed")
                                .font(.neueSubheadline)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Spacer()
                        }

                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(AVIATheme.teal)
                            Text("Awaiting access setup")
                                .font(.neueSubheadline)
                                .foregroundStyle(AVIATheme.textSecondary)
                            Spacer()
                        }
                    }
                    .padding(16)
                }
                .padding(.horizontal, 16)
            }

            Spacer()

            VStack(spacing: 16) {
                Text("You'll be notified once your access is ready.")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textTertiary)

                Button {
                    showSignOutAlert = true
                } label: {
                    Text("Sign Out")
                        .font(.neueSubheadlineMedium)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(AVIATheme.destructive)
                        .background(AVIATheme.destructive.opacity(0.08))
                        .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.horizontal, 28)
            }
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .onAppear { animatePulse = true }
        .task {
            await appViewModel.loadUserData()
        }
        .alert("Sign Out?", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                appViewModel.signOut()
            }
        } message: {
            Text("You'll need to sign in again to access your account.")
        }
    }
}
