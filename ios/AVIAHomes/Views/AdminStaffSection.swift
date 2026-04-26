import SwiftUI

struct AdminStaffSection: View {
    @Environment(AppViewModel.self) private var viewModel
    let searchText: String
    @Binding var selectedUserForEdit: ClientUser?

    private var staffList: [ClientUser] {
        var staff = viewModel.allRegisteredUsers.filter { $0.role.isAnyStaffRole }
        staff = Array(Dictionary(grouping: staff, by: \.id).compactMap(\.value.first))
        if !searchText.isEmpty {
            staff = staff.filter {
                $0.fullName.localizedStandardContains(searchText) ||
                $0.email.localizedStandardContains(searchText)
            }
        }
        return staff.sorted { $0.lastName < $1.lastName }
    }

    private var partnerList: [ClientUser] {
        var partners = viewModel.allRegisteredUsers.filter { $0.role == .partner }
        partners = Array(Dictionary(grouping: partners, by: \.id).compactMap(\.value.first))
        if !searchText.isEmpty {
            partners = partners.filter {
                $0.fullName.localizedStandardContains(searchText) ||
                $0.email.localizedStandardContains(searchText)
            }
        }
        return partners.sorted { $0.lastName < $1.lastName }
    }

    var body: some View {
        let pendingUsers = viewModel.allRegisteredUsers.filter { $0.role == .pending }

        VStack(spacing: 12) {
            if !pendingUsers.isEmpty {
                pendingUsersBanner(count: pendingUsers.count)
            }

            HStack(spacing: 12) {
                AdminMetricCard(value: "\(staffList.count)", label: "Staff Members", icon: "person.badge.shield.checkmark.fill", color: AVIATheme.timelessBrown)
                AdminMetricCard(value: "\(partnerList.count)", label: "Partners", icon: "person.2.fill", color: AVIATheme.timelessBrown)
            }
            .fixedSize(horizontal: false, vertical: true)

            if !pendingUsers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PENDING APPROVAL")
                        .font(.neueCaption2Medium)
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                    ForEach(filteredPending(pendingUsers), id: \.id) { user in
                        Button { selectedUserForEdit = user } label: {
                            AdminStaffUserRow(user: user)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("STAFF & WORKLOAD")
                    .font(.neueCaption2Medium)
                    .kerning(1.0)
                    .foregroundStyle(AVIATheme.textTertiary)
                if staffList.isEmpty {
                    AdminEmptyState(icon: "person.slash", title: "No staff found", subtitle: "Staff members will appear here")
                } else {
                    ForEach(staffList, id: \.id) { member in
                        AdminStaffWorkloadCard(member: member)
                    }
                }
            }

            if !partnerList.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PARTNERS")
                        .font(.neueCaption2Medium)
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                    ForEach(partnerList, id: \.id) { partner in
                        AdminPartnerCard(partner: partner)
                    }
                }
            }
        }
    }

    private func filteredPending(_ users: [ClientUser]) -> [ClientUser] {
        if searchText.isEmpty { return users }
        return users.filter {
            $0.fullName.localizedStandardContains(searchText) ||
            $0.email.localizedStandardContains(searchText)
        }
    }

    private func pendingUsersBanner(count: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(AVIATheme.aviaWhite)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(count) pending \(count == 1 ? "user" : "users")")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.aviaWhite)
                Text("Tap to review and assign roles")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.aviaWhite.opacity(0.8))
            }
            Spacer()
            NavigationLink { UserManagementView() } label: {
                Text("Review")
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
        .clipShape(.rect(cornerRadius: 13))
    }
}

struct AdminStaffUserRow: View {
    let user: ClientUser

    var body: some View {
        HStack(spacing: 12) {
            Text(user.initials.isEmpty ? "?" : user.initials)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.aviaWhite)
                .frame(width: 38, height: 38)
                .background {
                    if user.role.isPending {
                        AVIATheme.warning
                    } else {
                        AVIATheme.primaryGradient
                    }
                }
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? user.email : user.fullName)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(user.email)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(user.role.rawValue)
                .font(.neueCaption2Medium)
                .foregroundStyle(user.role.isPending ? AVIATheme.warning : AVIATheme.timelessBrown)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(user.role.isPending ? AVIATheme.warning.opacity(0.12) : AVIATheme.timelessBrown.opacity(0.12))
                .clipShape(.capsule)

            Image(systemName: "chevron.right")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .padding(12)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 11))
        .overlay {
            RoundedRectangle(cornerRadius: 11)
                .stroke(user.role.isPending ? AVIATheme.warning.opacity(0.3) : AVIATheme.surfaceBorder, lineWidth: 1)
        }
    }
}

struct AdminStaffWorkloadCard: View {
    @Environment(AppViewModel.self) private var viewModel
    let member: ClientUser

    private var assignedBuilds: [ClientBuild] {
        viewModel.allClientBuilds.filter { $0.assignedStaffId == member.id }
    }

    var body: some View {
        BentoCard(cornerRadius: 11) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(member.initials)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(width: 40, height: 40)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.fullName)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text(member.role.rawValue)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(assignedBuilds.count)")
                            .font(.neueCorpMedium(20))
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("builds")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }
                .padding(14)

                if !assignedBuilds.isEmpty {
                    let activeCount = assignedBuilds.filter { $0.currentStage != nil }.count
                    let avg = assignedBuilds.reduce(0.0) { $0 + $1.overallProgress } / Double(assignedBuilds.count)

                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                    HStack(spacing: 14) {
                        AdminWorkloadStat(label: "Assigned", value: "\(assignedBuilds.count)", color: AVIATheme.timelessBrown)
                        AdminWorkloadStat(label: "Active", value: "\(activeCount)", color: AVIATheme.warning)
                        AdminWorkloadStat(label: "Avg Progress", value: "\(Int(avg * 100))%", color: AVIATheme.success)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

struct AdminPartnerCard: View {
    @Environment(AppViewModel.self) private var viewModel
    let partner: ClientUser

    var body: some View {
        let assignedPackages = viewModel.packageAssignments.filter { $0.assignedPartnerIds.contains(partner.id) }
        let partnerClients = viewModel.allClientBuilds.filter { $0.salesPartnerId == partner.id }

        BentoCard(cornerRadius: 11) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(partner.initials.isEmpty ? "?" : partner.initials)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(width: 40, height: 40)
                        .background(AVIATheme.timelessBrown)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(partner.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? partner.email : partner.fullName)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text(partner.email)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    StatusBadge(title: "Partner", color: AVIATheme.timelessBrown)
                }
                .padding(14)

                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                HStack(spacing: 14) {
                    AdminWorkloadStat(label: "Packages", value: "\(assignedPackages.count)", color: AVIATheme.timelessBrown)
                    AdminWorkloadStat(label: "Clients", value: "\(partnerClients.count)", color: AVIATheme.timelessBrown)
                    AdminWorkloadStat(label: "Exclusive", value: "\(assignedPackages.filter(\.isExclusive).count)", color: AVIATheme.warning)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
    }
}
