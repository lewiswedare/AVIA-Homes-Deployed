import SwiftUI

struct EditProfileView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String
    @State private var lastName: String
    @State private var phone: String
    @State private var address: String
    @State private var isSaving = false
    @State private var showSaved = false

    init(user: ClientUser) {
        _firstName = State(initialValue: user.firstName)
        _lastName = State(initialValue: user.lastName)
        _phone = State(initialValue: user.phone)
        _address = State(initialValue: user.address)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    avatarSection

                    editSection(title: "Personal Details") {
                        editField(label: "First Name", text: $firstName, contentType: .givenName)
                        editField(label: "Last Name", text: $lastName, contentType: .familyName)
                        editField(label: "Phone", text: $phone, contentType: .telephoneNumber, keyboard: .phonePad)
                    }

                    editSection(title: "Mailing Address") {
                        editField(label: "Mailing Address", text: $address, contentType: .fullStreetAddress)
                    }

                    Text("Some details may require verification by AVIA Homes before changes take effect.")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textTertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AVIATheme.background)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(AVIATheme.timelessBrown)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveProfile()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save")
                                .font(.neueSubheadlineMedium)
                        }
                    }
                    .tint(AVIATheme.timelessBrown)
                    .disabled(!hasChanges || isSaving)
                }
            }
        }
        .presentationBackground(AVIATheme.background)
        .sensoryFeedback(.success, trigger: showSaved)
    }

    private var avatarSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Text(initials)
                    .font(.neueCorpMedium(28))
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 80, height: 80)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(Circle())

                Circle()
                    .stroke(AVIATheme.surfaceBorder, lineWidth: 3)
                    .frame(width: 86, height: 86)
            }

            Text("\(firstName) \(lastName)")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
            Text(appViewModel.currentUser.email)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var initials: String {
        let f = firstName.prefix(1)
        let l = lastName.prefix(1)
        return "\(f)\(l)"
    }

    private var hasChanges: Bool {
        let user = appViewModel.currentUser
        return firstName != user.firstName ||
            lastName != user.lastName ||
            phone != user.phone ||
            address != user.address
    }

    private func editSection<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
                .padding(.horizontal, 20)

            BentoCard(cornerRadius: 16) {
                VStack(spacing: 16) {
                    content()
                }
                .padding(16)
            }
            .padding(.horizontal, 16)
        }
    }

    private func editField(
        label: String,
        text: Binding<String>,
        contentType: UITextContentType? = nil,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textSecondary)
            TextField(label, text: text)
                .font(.neueSubheadline)
                .textContentType(contentType)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .foregroundStyle(AVIATheme.textPrimary)
                .tint(AVIATheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AVIATheme.surfaceElevated.opacity(0.5))
                .clipShape(.rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                }
        }
    }

    private func saveProfile() {
        isSaving = true
        Task {
            var user = appViewModel.currentUser
            user.firstName = firstName
            user.lastName = lastName
            user.phone = phone
            user.address = address
            await appViewModel.updateProfile(user: user)
            showSaved = true
            isSaving = false
            dismiss()
        }
    }
}
