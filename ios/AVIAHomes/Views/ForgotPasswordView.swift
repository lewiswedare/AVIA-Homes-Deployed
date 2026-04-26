import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @FocusState private var emailFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 32) {
                        VStack(spacing: 16) {
                            Image(systemName: "lock.rotation")
                                .font(.system(size: 48))
                                .foregroundStyle(AVIATheme.timelessBrown)
                                .frame(width: 88, height: 88)
                                .background(AVIATheme.timelessBrown.opacity(0.08))
                                .clipShape(Circle())

                            VStack(spacing: 6) {
                                Text("Reset Password")
                                    .font(.neueCorpMedium(24))
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text("Enter your email address and we'll send you a link to reset your password.")
                                    .font(.neueSubheadline)
                                    .foregroundStyle(AVIATheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.top, 32)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email")
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textSecondary)
                            TextField("Email", text: $email)
                                .font(.neueSubheadline)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .focused($emailFocused)
                                .submitLabel(.go)
                                .onSubmit { sendReset() }
                                .foregroundStyle(AVIATheme.textPrimary)
                                .tint(AVIATheme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(AVIATheme.cardBackground)
                            .clipShape(.rect(cornerRadius: 10))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                            }
                        }

                        Button(action: sendReset) {
                            Group {
                                if appViewModel.authService.isLoading {
                                    ProgressView().tint(AVIATheme.aviaWhite)
                                } else {
                                    Text("Send Reset Link")
                                        .font(.neueSubheadlineMedium)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .background(AVIATheme.primaryGradient)
                            .clipShape(.rect(cornerRadius: 11))
                        }
                        .disabled(email.isEmpty || appViewModel.authService.isLoading)
                        .opacity(email.isEmpty ? 0.6 : 1)
                    }
                    .padding(.horizontal, 28)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(AVIATheme.background)
            .tint(AVIATheme.textPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        }
        .presentationBackground(AVIATheme.background)
        .alert("Check Your Email", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("If an account exists for \(email), we've sent password reset instructions.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func sendReset() {
        Task {
            let success = await appViewModel.authService.sendPasswordReset(email: email)
            if success {
                showSuccess = true
            } else {
                errorMessage = appViewModel.authService.errorMessage ?? "Something went wrong."
                showError = true
            }
        }
    }
}
