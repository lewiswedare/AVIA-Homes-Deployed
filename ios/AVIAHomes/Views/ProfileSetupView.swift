import SwiftUI

struct ProfileSetupView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var currentStep = 0
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var companyName = ""
    @State private var animateIn = false

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            progressHeader

            TabView(selection: $currentStep) {
                personalInfoStep.tag(0)
                addressStep.tag(1)
                confirmationStep.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)

            bottomBar
        }
        .background(AVIATheme.background)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
                animateIn = true
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Image("AVIALogo")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 20)
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text(stepTitle)
                        .font(.neueCorpMedium(24))
                        .foregroundStyle(AVIATheme.textPrimary)
                }
                Spacer()
                Text("Step \(currentStep + 1) of \(totalSteps)")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textTertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AVIATheme.surfaceBorder)
                        .frame(height: 4)
                    Capsule()
                        .fill(AVIATheme.primaryGradient)
                        .frame(width: geo.size.width * stepProgress, height: 4)
                        .animation(.spring(response: 0.4), value: currentStep)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var stepTitle: String {
        switch currentStep {
        case 0: "About You"
        case 1: stepTwoTitle
        default: "All Set"
        }
    }

    private var stepTwoTitle: String {
        "Your Address"
    }

    private var stepProgress: Double {
        Double(currentStep + 1) / Double(totalSteps)
    }

    private var personalInfoStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Let's get to know you")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("This helps us personalise your experience")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }

                VStack(spacing: 14) {
                    setupField(label: "First Name", placeholder: "Enter your first name", text: $firstName, contentType: .givenName)
                    setupField(label: "Last Name", placeholder: "Enter your last name", text: $lastName, contentType: .familyName)
                    setupField(label: "Phone", placeholder: "0412 345 678", text: $phone, contentType: .telephoneNumber, keyboard: .phonePad)
                }
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 20)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var addressStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Where can we reach you?")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Your current mailing address for correspondence")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }

                VStack(spacing: 14) {
                    setupField(label: "Mailing Address", placeholder: "e.g. 14 Coastal Drive, Palmview QLD 4553", text: $address, contentType: .fullStreetAddress)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var confirmationStep: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(AVIATheme.success)

                    VStack(spacing: 6) {
                        Text("Welcome, \(firstName)!")
                            .font(.neueCorpMedium(24))
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("Your profile is ready. Here's a summary:")
                            .font(.neueSubheadline)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                }
                .padding(.top, 16)

                BentoCard(cornerRadius: 16) {
                    VStack(spacing: 0) {
                        summaryRow(icon: "person.fill", label: "Name", value: "\(firstName) \(lastName)")
                        Divider().padding(.leading, 48)
                        summaryRow(icon: "phone.fill", label: "Phone", value: phone.isEmpty ? "Not provided" : phone)
                        Divider().padding(.leading, 48)
                        if !address.isEmpty {
                            Divider().padding(.leading, 48)
                            summaryRow(icon: "location.fill", label: "Mailing Address", value: address)
                        }
                    }
                }

                Text("You can update these details anytime from Profile & Settings.")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
        }
    }

    private func summaryRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.timelessBrown)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textTertiary)
                Text(value)
                    .font(.neueSubheadline)
                    .foregroundStyle(AVIATheme.textPrimary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    Text("Back")
                        .font(.neueSubheadlineMedium)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .background(AVIATheme.cardBackground)
                        .clipShape(.rect(cornerRadius: 14))
                }
            }

            Button {
                if currentStep < totalSteps - 1 {
                    withAnimation { currentStep += 1 }
                } else {
                    completeSetup()
                }
            } label: {
                Text(currentStep == totalSteps - 1 ? "Get Started" : "Continue")
                    .font(.neueSubheadlineMedium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 14))
            }
            .disabled(currentStep == 0 && (firstName.isEmpty || lastName.isEmpty))
            .opacity(currentStep == 0 && (firstName.isEmpty || lastName.isEmpty) ? 0.6 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AVIATheme.background)
    }

    private func setupField(
        label: String,
        placeholder: String,
        text: Binding<String>,
        contentType: UITextContentType? = nil,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textSecondary)
            TextField(placeholder, text: text)
                .font(.neueSubheadline)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
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

    private func completeSetup() {
        var user = appViewModel.currentUser
        user.firstName = firstName
        user.lastName = lastName
        user.phone = phone
        user.address = address
        user.role = .client
        user.profileCompleted = true
        Task {
            await appViewModel.completeProfileSetup(user: user)
        }
    }
}
