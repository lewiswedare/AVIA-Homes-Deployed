import SwiftUI

struct ProfileView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var notificationsEnabled = true
    @State private var buildUpdates = true
    @State private var documentAlerts = true
    @State private var showSignOutAlert = false
    @State private var showEditProfile = false

    private var isClient: Bool { viewModel.currentRole == .client }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                profileHeader

                if isClient {
                    settingsSection(title: "Home Details") {
                        DetailRow(icon: "house.fill", title: "Home Design", value: viewModel.currentUser.homeDesign)
                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 48)
                        DetailRow(icon: "mappin.circle.fill", title: "Lot", value: viewModel.currentUser.lotNumber)
                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 48)
                        DetailRow(icon: "location.fill", title: "Mailing Address", value: viewModel.currentUser.address)
                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 48)
                        DetailRow(icon: "calendar", title: "Contract Date", value: viewModel.currentUser.contractDate.formatted(date: .long, time: .omitted))
                    }
                } else {
                    settingsSection(title: "Account") {
                        DetailRow(icon: "location.fill", title: "Address", value: viewModel.currentUser.address.isEmpty ? "Not set" : viewModel.currentUser.address)
                    }
                }

                settingsSection(title: "Contact") {
                    DetailRow(icon: "envelope.fill", title: "Email", value: viewModel.currentUser.email)
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 48)
                    DetailRow(icon: "phone.fill", title: "Phone", value: viewModel.currentUser.phone)
                }

                settingsSection(title: "Notifications") {
                    ToggleRow(icon: "bell.fill", title: "Push Notifications", isOn: $notificationsEnabled)
                    if notificationsEnabled {
                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 48)
                        ToggleRow(icon: "hammer.fill", title: "Build Stage Updates", isOn: $buildUpdates)
                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 48)
                        ToggleRow(icon: "doc.fill", title: "New Document Alerts", isOn: $documentAlerts)
                    }
                }

                settingsSection(title: "Support") {
                    LinkRow(icon: "phone.fill", title: "Call AVIA Homes", url: "tel:0756545123")
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 48)
                    LinkRow(icon: "envelope.fill", title: "Email Support", url: "mailto:info@aviahomes.com.au")
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 48)
                    LinkRow(icon: "safari.fill", title: "Visit Website", url: "https://www.aviahomes.com.au")
                }

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
                .padding(.horizontal, 16)

                Image("AVIALogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 28)
                    .opacity(0.3)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
            .padding(.bottom, 20)
        }
        .background(AVIATheme.background)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .alert("Sign Out?", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                viewModel.signOut()
            }
        } message: {
            Text("You'll need to sign in again to access your account.")
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(user: viewModel.currentUser)
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 16) {
            UserAvatarView(user: viewModel.currentUser, size: 56, fontSize: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.currentUser.fullName)
                    .font(.neueCorpMedium(20))
                    .foregroundStyle(AVIATheme.textPrimary)
                if isClient && !viewModel.currentUser.homeDesign.isEmpty {
                    Text(viewModel.currentUser.homeDesign)
                        .font(.neueSubheadline)
                        .foregroundStyle(AVIATheme.textSecondary)
                } else {
                    Text(viewModel.currentUser.email)
                        .font(.neueSubheadline)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
            }
            Spacer()
            Button {
                showEditProfile = true
            } label: {
                Image(systemName: "pencil")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(width: 36, height: 36)
                    .background(AVIATheme.timelessBrown.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(18)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 18))
        .padding(.horizontal, 16)
    }

    private func settingsSection<Content: View>(title: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
                .padding(.horizontal, 20)

            BentoCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    content()
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.timelessBrown)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
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
}

struct ToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.neueSubheadline)
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(width: 28)
                Text(title)
                    .font(.neueSubheadline)
                    .foregroundStyle(AVIATheme.textPrimary)
            }
        }
        .tint(AVIATheme.timelessBrown)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct LinkRow: View {
    let icon: String
    let title: String
    let url: String

    var body: some View {
        if let destination = URL(string: url) {
            Link(destination: destination) {
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.neueSubheadline)
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .frame(width: 28)
                    Text(title)
                        .font(.neueSubheadline)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
}
