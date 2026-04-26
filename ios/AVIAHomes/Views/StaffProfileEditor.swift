import SwiftUI

struct StaffProfileEditor: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let staffUser: ClientUser

    @State private var displayTitle: String = ""
    @State private var phone: String = ""
    @State private var avatarUrl: String = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BentoCard(cornerRadius: 13) {
                        VStack(spacing: 14) {
                            profileField(label: "Display Title", text: $displayTitle, placeholder: "e.g. Pre-Site Coordinator")
                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                            profileField(label: "Phone", text: $phone, placeholder: "e.g. 0468040280")
                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                            profileField(label: "Avatar URL", text: $avatarUrl, placeholder: "https://...")
                        }
                        .padding(16)
                    }

                    PremiumButton("Save Changes", icon: "checkmark", style: .primary) {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(AVIATheme.background)
            .navigationTitle("Edit Staff Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.neueSubheadline)
                }
            }
            .onAppear {
                displayTitle = staffUser.displayTitle ?? ""
                phone = staffUser.phone
                avatarUrl = staffUser.avatarUrl ?? ""
            }
        }
    }

    private func profileField(label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.textTertiary)
                .textCase(.uppercase)
                .kerning(0.5)
            TextField(placeholder, text: text)
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textPrimary)
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        var fields: [String: String] = [:]
        fields["display_title"] = displayTitle
        fields["phone"] = phone
        fields["avatar_url"] = avatarUrl
        await SupabaseService.shared.updateProfileField(userId: staffUser.id, fields: fields)
        dismiss()
    }
}
