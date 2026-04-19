import SwiftUI

struct UserManagementView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var searchText = ""
    @State private var filterRole: UserRole?
    @State private var selectedUser: ClientUser?

    private var filteredUsers: [ClientUser] {
        var users = viewModel.allRegisteredUsers
        if let filterRole {
            users = users.filter { $0.role == filterRole }
        }
        if !searchText.isEmpty {
            users = users.filter {
                $0.fullName.localizedStandardContains(searchText) ||
                $0.email.localizedStandardContains(searchText)
            }
        }
        return users.sorted { lhs, rhs in
            if lhs.role == .pending && rhs.role != .pending { return true }
            if lhs.role != .pending && rhs.role == .pending { return false }
            return lhs.lastName < rhs.lastName
        }
    }

    private var pendingCount: Int {
        viewModel.allRegisteredUsers.filter { $0.role == .pending }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if pendingCount > 0 {
                    pendingBanner
                }

                filterBar

                if filteredUsers.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredUsers, id: \.id) { user in
                            Button {
                                selectedUser = user
                            } label: {
                                userRow(user)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(AVIATheme.background)
        .navigationTitle("User Management")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search users")
        .sheet(item: $selectedUser) { user in
            UserRoleAssignmentSheet(user: user)
        }
    }

    private var pendingBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(AVIATheme.aviaWhite)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(pendingCount) pending \(pendingCount == 1 ? "user" : "users")")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.aviaWhite)
                Text("Tap to review and assign roles")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.aviaWhite.opacity(0.8))
            }

            Spacer()

            Button {
                withAnimation { filterRole = .pending }
            } label: {
                Text("View")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(AVIATheme.aviaWhite)
                    .clipShape(.capsule)
            }
        }
        .padding(14)
        .background(AVIATheme.primaryGradient)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(label: "All", role: nil)
                filterChip(label: "Pending", role: .pending)
                ForEach(UserRole.assignableRoles, id: \.self) { role in
                    filterChip(label: role.rawValue, role: role)
                }
            }
        }
        .contentMargins(.horizontal, 0)
    }

    private func filterChip(label: String, role: UserRole?) -> some View {
        let isSelected = filterRole == role
        return Button {
            withAnimation(.spring(response: 0.3)) {
                filterRole = role
            }
        } label: {
            Text(label)
                .font(.neueCaptionMedium)
                .foregroundStyle(isSelected ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? AVIATheme.timelessBrown : AVIATheme.cardBackground)
                .clipShape(.capsule)
                .overlay {
                    Capsule().stroke(isSelected ? Color.clear : AVIATheme.surfaceBorder, lineWidth: 1)
                }
        }
    }

    private func userRow(_ user: ClientUser) -> some View {
        HStack(spacing: 14) {
            Text(user.initials.isEmpty ? "?" : user.initials)
                .font(.neueCorpMedium(14))
                .foregroundStyle(AVIATheme.aviaWhite)
                .frame(width: 42, height: 42)
                .background {
                    Group {
                        if user.role.isPending {
                            AVIATheme.warning
                        } else {
                            AVIATheme.primaryGradient
                        }
                    }
                }
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(user.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? user.email : user.fullName)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .lineLimit(1)
                Text(user.email)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            roleBadge(user.role)

            Image(systemName: "chevron.right")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .padding(14)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(user.role.isPending ? AVIATheme.warning.opacity(0.3) : AVIATheme.surfaceBorder, lineWidth: 1)
        }
    }

    private func roleBadge(_ role: UserRole) -> some View {
        let color: Color = role.isPending ? AVIATheme.warning : AVIATheme.timelessBrown
        return Text(role.rawValue)
            .font(.neueCaption2Medium)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .overlay(Capsule().stroke(color, lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 36))
                .foregroundStyle(AVIATheme.textTertiary)
            Text("No users found")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textSecondary)
            Text("Try adjusting your search or filter")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct UserRoleAssignmentSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    let user: ClientUser
    @State private var selectedRole: UserRole
    @State private var isSaving = false

    init(user: ClientUser) {
        self.user = user
        _selectedRole = State(initialValue: user.role == .pending ? .client : user.role)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    userHeader

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Assign Role")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)

                        VStack(spacing: 8) {
                            ForEach(UserRole.assignableRoles, id: \.self) { role in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedRole = role
                                    }
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: role.icon)
                                            .font(.neueSubheadline)
                                            .foregroundStyle(selectedRole == role ? AVIATheme.timelessBrown : AVIATheme.textTertiary)
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(role.rawValue)
                                                .font(.neueSubheadlineMedium)
                                                .foregroundStyle(AVIATheme.textPrimary)
                                            Text(role.description)
                                                .font(.neueCaption)
                                                .foregroundStyle(AVIATheme.textSecondary)
                                        }

                                        Spacer()

                                        Image(systemName: selectedRole == role ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 22))
                                            .foregroundStyle(selectedRole == role ? AVIATheme.timelessBrown : AVIATheme.surfaceBorder)
                                    }
                                    .padding(14)
                                    .background(selectedRole == role ? AVIATheme.timelessBrown.opacity(0.06) : AVIATheme.cardBackground)
                                    .clipShape(.rect(cornerRadius: 14))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(selectedRole == role ? AVIATheme.timelessBrown.opacity(0.4) : AVIATheme.surfaceBorder, lineWidth: selectedRole == role ? 1.5 : 1)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Button(action: saveRole) {
                        Group {
                            if isSaving {
                                ProgressView().tint(AVIATheme.aviaWhite)
                            } else {
                                Text("Save Role")
                                    .font(.neueSubheadlineMedium)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .disabled(isSaving)
                    .padding(.horizontal, 20)
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("Assign Role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(AVIATheme.timelessBrown)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AVIATheme.background)
    }

    private var userHeader: some View {
        VStack(spacing: 12) {
            Text(user.initials.isEmpty ? "?" : user.initials)
                .font(.neueCorpMedium(24))
                .foregroundStyle(AVIATheme.aviaWhite)
                .frame(width: 64, height: 64)
                .background {
                    Group {
                        if user.role.isPending {
                            AVIATheme.warning
                        } else {
                            AVIATheme.primaryGradient
                        }
                    }
                }
                .clipShape(Circle())

            VStack(spacing: 4) {
                Text(user.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? "New User" : user.fullName)
                    .font(.neueCorpMedium(20))
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(user.email)
                    .font(.neueSubheadline)
                    .foregroundStyle(AVIATheme.textSecondary)
            }

            if user.role.isPending {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.neueCaption2)
                    Text("Pending Approval")
                        .font(.neueCaptionMedium)
                }
                .foregroundStyle(AVIATheme.warning)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AVIATheme.warning.opacity(0.12))
                .clipShape(.capsule)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func saveRole() {
        isSaving = true
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            viewModel.assignRole(selectedRole, to: user.id)
            isSaving = false
            dismiss()
        }
    }
}
