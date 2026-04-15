import SwiftUI

struct DesignEnquiryFormView: View {
    let designName: String
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var message: String = ""
    @State private var isSubmitting: Bool = false
    @State private var showSuccess: Bool = false
    @State private var errorMessage: String?
    @State private var hasPrefilledFromProfile: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    designHeader
                    formFields
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.destructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    submitButton
                }
                .padding(20)
            }
            .background(AVIATheme.background)
            .navigationTitle("Enquire for Pricing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AVIATheme.textSecondary)
                }
            }
            .alert("Enquiry Submitted", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Thanks for your interest in the \(designName). Our team will be in touch shortly.")
            }
            .onAppear { prefillFromProfile() }
        }
    }

    private var designHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "house.fill")
                .font(.neueTitle3)
                .foregroundStyle(AVIATheme.teal)
            VStack(alignment: .leading, spacing: 2) {
                Text("Enquiring about")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textTertiary)
                Text(designName)
                    .font(.neueHeadline)
                    .foregroundStyle(AVIATheme.textPrimary)
            }
            Spacer()
        }
        .padding(16)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var formFields: some View {
        VStack(spacing: 14) {
            fieldRow(title: "Full Name *", text: $fullName, placeholder: "Enter your full name", keyboardType: .default)
            fieldRow(title: "Email *", text: $email, placeholder: "Enter your email address", keyboardType: .emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            fieldRow(title: "Phone Number", text: $phone, placeholder: "Enter your phone number", keyboardType: .phonePad)
            VStack(alignment: .leading, spacing: 6) {
                Text("Message / Notes")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                TextEditor(text: $message)
                    .font(.neueSubheadline)
                    .frame(minHeight: 80)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(AVIATheme.cardBackgroundAlt)
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                    )
            }
        }
    }

    private func fieldRow(title: String, text: Binding<String>, placeholder: String, keyboardType: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
            TextField(placeholder, text: text)
                .font(.neueSubheadline)
                .keyboardType(keyboardType)
                .padding(12)
                .background(AVIATheme.cardBackgroundAlt)
                .clipShape(.rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                )
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.neueSubheadlineMedium)
                    Text("Submit Enquiry")
                        .font(.neueSubheadlineMedium)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(isFormValid ? AVIATheme.tealGradient : LinearGradient(colors: [AVIATheme.textTertiary, AVIATheme.textTertiary], startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(!isFormValid || isSubmitting)
    }

    private var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
        && isValidEmail(email)
    }

    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        let parts = trimmed.split(separator: "@", maxSplits: 2)
        guard parts.count == 2, !parts[0].isEmpty, parts[1].contains(".") else { return false }
        return true
    }

    private func prefillFromProfile() {
        guard !hasPrefilledFromProfile else { return }
        hasPrefilledFromProfile = true
        let user = viewModel.currentUser
        if !user.id.isEmpty {
            if fullName.isEmpty {
                let name = user.fullName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { fullName = name }
            }
            if email.isEmpty && !user.email.isEmpty {
                email = user.email
            }
            if phone.isEmpty && !user.phone.isEmpty {
                phone = user.phone
            }
        }
    }

    private func submit() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let row = DesignEnquiryInsertRow(
            designName: designName,
            fullName: fullName.trimmingCharacters(in: .whitespaces),
            email: email.trimmingCharacters(in: .whitespaces),
            phone: phone.trimmingCharacters(in: .whitespaces),
            message: message.trimmingCharacters(in: .whitespaces).isEmpty ? nil : message.trimmingCharacters(in: .whitespaces)
        )

        let success = await SupabaseService.shared.submitDesignEnquiry(row)
        if success {
            showSuccess = true
        } else {
            errorMessage = "Something went wrong. Please try again."
        }
    }
}
