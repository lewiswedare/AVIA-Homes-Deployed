import SwiftUI

struct SignUpView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var acceptedTerms = false
    @State private var showTermsSheet = false
    @State private var showPrivacySheet = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password, confirm }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    Color(hex: "E1DDDC")
                        .frame(height: geo.size.height * 0.32 + geo.safeAreaInsets.top)
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
                                    .init(color: AVIATheme.background.opacity(0.4), location: 0.5),
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

                    VStack(spacing: 24) {
                        Text("Create Account")
                            .font(.neueCorpMedium(28))
                            .foregroundStyle(AVIATheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 14) {
                            fieldGroup(label: "Email") {
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
                            }

                            fieldGroup(label: "Password") {
                                SecureField("Create a password", text: $password)
                                    .font(.neueSubheadline)
                                    .textContentType(.newPassword)
                                    .focused($focusedField, equals: .password)
                                    .submitLabel(.next)
                                    .onSubmit { focusedField = .confirm }
                                    .foregroundStyle(AVIATheme.textPrimary)
                            }

                            fieldGroup(label: "Confirm Password") {
                                SecureField("Re-enter your password", text: $confirmPassword)
                                    .font(.neueSubheadline)
                                    .textContentType(.newPassword)
                                    .focused($focusedField, equals: .confirm)
                                    .submitLabel(.go)
                                    .onSubmit { signUp() }
                                    .foregroundStyle(AVIATheme.textPrimary)
                            }

                            if !password.isEmpty {
                                passwordStrengthIndicator
                            }
                        }

                        HStack(alignment: .top, spacing: 10) {
                            Text(termsAttributedString)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .environment(\.openURL, OpenURLAction { url in
                                    if url.absoluteString == "avia://terms" {
                                        showTermsSheet = true
                                    } else if url.absoluteString == "avia://privacy" {
                                        showPrivacySheet = true
                                    }
                                    return .handled
                                })

                            Toggle("", isOn: $acceptedTerms)
                                .labelsHidden()
                                .tint(AVIATheme.timelessBrown)
                                .toggleStyle(.switch)
                                .fixedSize()
                        }

                        Button(action: signUp) {
                            Group {
                                if appViewModel.authService.isLoading {
                                    ProgressView().tint(AVIATheme.aviaWhite)
                                } else {
                                    Text("Create Account")
                                        .font(.neueSubheadlineMedium)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .background(AVIATheme.primaryGradient)
                            .clipShape(.rect(cornerRadius: 14))
                        }
                        .disabled(!isFormValid || appViewModel.authService.isLoading)
                        .opacity(isFormValid ? 1 : 0.6)

                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 4) {
                                Text("Already have an account?")
                                    .font(.neueSubheadline)
                                    .foregroundStyle(AVIATheme.textSecondary)
                                Text("Sign In")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.timelessBrown)
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 28)

                    Spacer(minLength: 40)
                }
                .frame(minHeight: geo.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            .ignoresSafeArea(edges: [.top, .horizontal])
        }
        .background(AVIATheme.background)
        .tint(AVIATheme.textPrimary)
        .alert("Sign Up Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showTermsSheet) {
            LegalSheetView(title: "Terms of Service", content: Self.demoTermsOfService)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showPrivacySheet) {
            LegalSheetView(title: "Privacy Policy", content: Self.demoPrivacyPolicy)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && acceptedTerms
    }

    private var passwordStrengthIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index < passwordStrength ? strengthColor : AVIATheme.surfaceBorder)
                    .frame(height: 3)
            }
            Text(strengthLabel)
                .font(.neueCaption2)
                .foregroundStyle(strengthColor)
        }
    }

    private var passwordStrength: Int {
        var score = 0
        if password.count >= 6 { score += 1 }
        if password.count >= 10 { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        return score
    }

    private var strengthColor: Color {
        switch passwordStrength {
        case 0...1: AVIATheme.destructive
        case 2: AVIATheme.warning
        default: AVIATheme.success
        }
    }

    private var strengthLabel: String {
        switch passwordStrength {
        case 0...1: "Weak"
        case 2: "Fair"
        case 3: "Good"
        default: "Strong"
        }
    }

    private var termsAttributedString: AttributedString {
        var full = AttributedString("I agree to the ")
        var terms = AttributedString("Terms of Service")
        terms.underlineStyle = .single
        terms.foregroundColor = UIColor(AVIATheme.timelessBrown)
        terms.link = URL(string: "avia://terms")
        var and = AttributedString(" and ")
        var privacy = AttributedString("Privacy Policy")
        privacy.underlineStyle = .single
        privacy.foregroundColor = UIColor(AVIATheme.timelessBrown)
        privacy.link = URL(string: "avia://privacy")
        full.foregroundColor = UIColor(AVIATheme.textSecondary)
        and.foregroundColor = UIColor(AVIATheme.textSecondary)
        return full + terms + and + privacy
    }

    private func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textSecondary)
            content()
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

    private static let demoTermsOfService = """
AVIA Homes — Terms of Service

Last updated: April 2025

1. ACCEPTANCE OF TERMS

By accessing or using the AVIA Homes client portal application ("the App"), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the App.

2. DESCRIPTION OF SERVICE

The App provides AVIA Homes clients with tools to manage their new home building journey, including but not limited to:
• Viewing build progress and stage updates
• Making colour and finish selections for their home
• Accessing contracts, plans, and other documents
• Submitting maintenance requests and support queries
• Communicating with the AVIA Homes team

3. USER ACCOUNTS

You are responsible for maintaining the confidentiality of your account credentials. You agree to notify AVIA Homes immediately of any unauthorised use of your account. AVIA Homes reserves the right to suspend or terminate accounts at its discretion.

4. USER CONDUCT

You agree not to:
• Use the App for any unlawful purpose
• Attempt to gain unauthorised access to any part of the App
• Interfere with or disrupt the App's functionality
• Upload malicious content or files
• Share your account credentials with third parties

5. COLOUR SELECTIONS & SPECIFICATIONS

Colour and material selections made through the App are subject to availability and final confirmation by AVIA Homes. Digital representations of colours may vary from actual products due to screen settings. Final selections will be confirmed in writing by your AVIA Homes consultant.

6. INTELLECTUAL PROPERTY

All content in the App, including home designs, floor plans, specifications, images, and branding, is the property of AVIA Homes and is protected by copyright and intellectual property laws. You may not reproduce, distribute, or create derivative works without written permission.

7. LIMITATION OF LIABILITY

The App is provided "as is" without warranties of any kind. AVIA Homes shall not be liable for any indirect, incidental, or consequential damages arising from your use of the App. Build timelines, specifications, and other information displayed are estimates and subject to change.

8. PRIVACY

Your use of the App is also governed by our Privacy Policy. Please review it to understand our data collection and usage practices.

9. MODIFICATIONS

AVIA Homes reserves the right to modify these Terms at any time. Continued use of the App after changes constitutes acceptance of the modified Terms. We will notify you of significant changes through the App.

10. GOVERNING LAW

These Terms are governed by the laws of the State of Victoria, Australia. Any disputes will be subject to the exclusive jurisdiction of the courts of Victoria.

11. CONTACT

For questions about these Terms, please contact:
AVIA Homes
Email: info@aviahomes.com.au
Phone: 1300 AVIA HOMES
"""

    private static let demoPrivacyPolicy = """
AVIA Homes — Privacy Policy

Last updated: April 2025

1. OVERVIEW

AVIA Homes ("we", "our", "us") is committed to protecting your personal information. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our client portal application.

2. INFORMATION WE COLLECT

Personal Information:
• Full name and contact details (email, phone, address)
• Account credentials
• Home build details and lot information
• Colour and finish selections
• Documents you upload or we provide to you
• Support request details and correspondence

Automatically Collected Information:
• Device information (model, operating system)
• App usage data and analytics
• Push notification tokens
• Log data and error reports

3. HOW WE USE YOUR INFORMATION

We use your information to:
• Provide and maintain the App and its features
• Process and manage your colour selections
• Deliver build progress updates and notifications
• Respond to your support requests and queries
• Send important communications about your build
• Improve our services and user experience
• Comply with legal obligations

4. INFORMATION SHARING

We may share your information with:
• AVIA Homes staff involved in your build (site supervisors, consultants, administrators)
• Trusted third-party service providers who assist in operating the App
• Partner builders and suppliers as necessary for your build
• Legal authorities when required by law

We do not sell your personal information to third parties.

5. DATA SECURITY

We implement appropriate technical and organisational measures to protect your personal information, including encryption of data in transit and at rest, secure authentication, and regular security assessments.

6. DATA RETENTION

We retain your personal information for as long as your account is active and for a reasonable period afterward for legal and business purposes. You may request deletion of your data by contacting us.

7. YOUR RIGHTS

You have the right to:
• Access the personal information we hold about you
• Request correction of inaccurate information
• Request deletion of your information
• Opt out of non-essential communications
• Lodge a complaint with the relevant privacy authority

8. PUSH NOTIFICATIONS

With your consent, we send push notifications for build updates, document availability, and important messages. You can manage notification preferences in the App settings or your device settings.

9. CHILDREN'S PRIVACY

The App is not intended for use by children under 18. We do not knowingly collect personal information from children.

10. CHANGES TO THIS POLICY

We may update this Privacy Policy from time to time. We will notify you of any material changes through the App or via email.

11. CONTACT US

If you have questions about this Privacy Policy or our data practices, please contact:

AVIA Homes — Privacy Officer
Email: privacy@aviahomes.com.au
Phone: 1300 AVIA HOMES
Address: Melbourne, Victoria, Australia

This policy is compliant with the Australian Privacy Principles (APPs) under the Privacy Act 1988 (Cth).
"""

    private func signUp() {
        Task {
            let success = await appViewModel.authService.signUp(
                email: email,
                password: password,
                confirmPassword: confirmPassword
            )
            if success {
                await appViewModel.handleSignUp(email: email)
            } else {
                errorMessage = appViewModel.authService.errorMessage ?? "Something went wrong."
                showError = true
            }
        }
    }
}
