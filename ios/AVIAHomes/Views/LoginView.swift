import SwiftUI

struct LoginView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSignUp = false
    @State private var showForgotPassword = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    Color(hex: "E1DDDC")
                        .frame(height: geo.size.height * 0.5 + geo.safeAreaInsets.top)
                        .overlay {
                            Image("signin_background")
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                        }
                        .overlay {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: AVIATheme.background.opacity(0.3), location: 0.55),
                                    .init(color: AVIATheme.background, location: 1.0),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .overlay(alignment: .bottomLeading) {
                            Image("AVIALogo")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 140)
                                .foregroundStyle(AVIATheme.textPrimary)
                                .padding(.horizontal, 28)
                                .padding(.bottom, 32)
                        }
                        .clipShape(
                            UnevenRoundedRectangle(
                                bottomLeadingRadius: 32,
                                bottomTrailingRadius: 32
                            )
                        )

                    VStack(spacing: 28) {
                        VStack(spacing: 14) {
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
                                    .focused($focusedField, equals: .email)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .password }
                                    .foregroundStyle(AVIATheme.textPrimary)
                                    .tint(AVIATheme.textPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(AVIATheme.cardBackground)
                                .clipShape(.rect(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Password")
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textSecondary)
                                SecureField("Enter your password", text: $password)
                                    .font(.neueSubheadline)
                                    .textContentType(.password)
                                    .focused($focusedField, equals: .password)
                                    .submitLabel(.go)
                                    .onSubmit { signIn() }
                                    .foregroundStyle(AVIATheme.textPrimary)
                                    .tint(AVIATheme.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(AVIATheme.cardBackground)
                                    .clipShape(.rect(cornerRadius: 12))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                                    }
                            }
                        }

                        Button(action: signIn) {
                            Group {
                                if appViewModel.authService.isLoading {
                                    ProgressView().tint(AVIATheme.aviaWhite)
                                } else {
                                    Text("Sign In")
                                        .font(.neueSubheadlineMedium)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .background(AVIATheme.primaryGradient)
                            .clipShape(.rect(cornerRadius: 14))
                        }
                        .disabled(email.isEmpty || password.isEmpty || appViewModel.authService.isLoading)
                        .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)

                        Button("Forgot Password?") {
                            showForgotPassword = true
                        }
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)

                        dividerRow

                        Button {
                            showSignUp = true
                        } label: {
                            Text("Create Account")
                                .font(.neueSubheadlineMedium)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundStyle(AVIATheme.timelessBrown)
                                .background(AVIATheme.timelessBrown.opacity(0.08))
                                .clipShape(.rect(cornerRadius: 14))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(AVIATheme.timelessBrown.opacity(0.2), lineWidth: 1)
                                }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 32)

                    Spacer(minLength: 40)
                }
                .frame(minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: [.top, .horizontal])
        }
        .background(AVIATheme.background)
        .tint(AVIATheme.textPrimary)
        .alert("Sign In Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showSignUp) {
            SignUpView()
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
    }

    private var dividerRow: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(AVIATheme.surfaceBorder)
                .frame(height: 1)
            Text("or")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
            Rectangle()
                .fill(AVIATheme.surfaceBorder)
                .frame(height: 1)
        }
    }

    private func signIn() {
        Task {
            let success = await appViewModel.signIn(email: email, password: password)
            if !success {
                errorMessage = appViewModel.authService.errorMessage ?? "Please check your email and password."
                showError = true
            }
        }
    }
}
