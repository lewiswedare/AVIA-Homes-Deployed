import SwiftUI
import PhotosUI

struct EditProfileView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String
    @State private var lastName: String
    @State private var phone: String
    @State private var address: String
    @State private var avatarUrl: String
    @State private var avatarPreview: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false
    @State private var avatarError: String?
    @State private var isSaving = false
    @State private var showSaved = false

    init(user: ClientUser) {
        _firstName = State(initialValue: user.firstName)
        _lastName = State(initialValue: user.lastName)
        _phone = State(initialValue: user.phone)
        _address = State(initialValue: user.address)
        _avatarUrl = State(initialValue: user.avatarUrl ?? "")
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
                avatarImage
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())

                Circle()
                    .stroke(AVIATheme.surfaceBorder, lineWidth: 3)
                    .frame(width: 102, height: 102)

                if isUploadingAvatar {
                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 96, height: 96)
                    ProgressView()
                        .tint(AVIATheme.aviaWhite)
                }
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.neueCaption)
                    Text(avatarUrl.isEmpty ? "Add Photo" : "Change Photo")
                        .font(.neueCaptionMedium)
                }
                .foregroundStyle(AVIATheme.timelessBrown)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(AVIATheme.timelessBrown.opacity(0.1))
                .clipShape(Capsule())
            }
            .disabled(isUploadingAvatar)

            if !avatarUrl.isEmpty && !isUploadingAvatar {
                Button(role: .destructive) {
                    avatarUrl = ""
                    avatarPreview = nil
                } label: {
                    Text("Remove Photo")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.destructive)
                }
            }

            if let avatarError {
                Text(avatarError)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.destructive)
            }

            Text("\(firstName) \(lastName)")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
                .padding(.top, 4)
            Text(appViewModel.currentUser.email)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .onChange(of: photoItem) { _, newItem in
            guard let newItem else { return }
            Task { await handlePhotoSelection(newItem) }
        }
    }

    @ViewBuilder
    private var avatarImage: some View {
        if let preview = avatarPreview {
            Image(uiImage: preview)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if !avatarUrl.isEmpty, let url = URL(string: avatarUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    initialsCircle
                }
            }
        } else {
            initialsCircle
        }
    }

    private var initialsCircle: some View {
        Text(initials)
            .font(.neueCorpMedium(32))
            .foregroundStyle(AVIATheme.aviaWhite)
            .frame(width: 96, height: 96)
            .background(AVIATheme.primaryGradient)
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem) async {
        isUploadingAvatar = true
        avatarError = nil
        defer { isUploadingAvatar = false }

        guard let data = await ImageUploadService.shared.loadTransferable(from: item) else {
            avatarError = "Couldn't load the selected image."
            return
        }
        if let uiImg = UIImage(data: data) {
            avatarPreview = uiImg
        }

        let userId = appViewModel.currentUser.id.isEmpty ? "user" : appViewModel.currentUser.id
        let fileName = "\(userId)_\(Int(Date().timeIntervalSince1970)).png"
        if let url = await ImageUploadService.shared.uploadImage(data, folder: "avatars", fileName: fileName) {
            avatarUrl = url
        } else {
            avatarError = "Upload failed. Please try again."
            avatarPreview = nil
        }
        photoItem = nil
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
            address != user.address ||
            avatarUrl != (user.avatarUrl ?? "")
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
            user.avatarUrl = avatarUrl.isEmpty ? nil : avatarUrl
            await appViewModel.updateProfile(user: user)
            showSaved = true
            isSaving = false
            dismiss()
        }
    }
}
