import SwiftUI

struct AdminClientsSection: View {
    @Environment(AppViewModel.self) private var viewModel
    let searchText: String

    @State private var crmProfiles: [String: ClientCRMProfile] = [:]
    @State private var statusFilter: LeadStatus? = nil
    @State private var isLoadingProfiles: Bool = false
    @State private var viewMode: ClientsViewMode = .list

    enum ClientsViewMode: String, CaseIterable, Identifiable {
        case list, pipeline
        var id: String { rawValue }
        var label: String { self == .list ? "List" : "Pipeline" }
        var icon: String { self == .list ? "list.bullet" : "rectangle.split.3x1.fill" }
    }

    private var clientsList: [ClientUser] {
        var clients = viewModel.allRegisteredUsers.filter { $0.role == .client }
        clients = Array(Dictionary(grouping: clients, by: \.id).compactMap(\.value.first))
        if !searchText.isEmpty {
            clients = clients.filter {
                $0.fullName.localizedStandardContains(searchText) ||
                $0.email.localizedStandardContains(searchText)
            }
        }
        return clients.sorted { $0.lastName < $1.lastName }
    }

    private func filteredClients(_ all: [ClientUser]) -> [ClientUser] {
        guard let filter = statusFilter else { return all }
        return all.filter { (crmProfiles[$0.id]?.leadStatus ?? .new) == filter }
    }

    private var followUpsDueCount: Int {
        let now = Date()
        return crmProfiles.values.filter {
            guard let next = $0.nextFollowUpAt else { return false }
            return next <= now.addingTimeInterval(86400 * 2)
        }.count
    }

    var body: some View {
        let allClients = clientsList
        let clientsWithBuildIds = Set(viewModel.allClientBuilds.flatMap(\.allClientIds))
        let filtered = filteredClients(allClients)

        VStack(spacing: 12) {
            HStack(spacing: 12) {
                AdminMetricCard(value: "\(allClients.count)", label: "Total Clients", icon: "person.2.fill", color: AVIATheme.timelessBrown)
                AdminMetricCard(value: "\(allClients.filter { clientsWithBuildIds.contains($0.id) }.count)", label: "With Builds", icon: "building.2.fill", color: AVIATheme.success)
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Picker("View", selection: $viewMode) {
                    ForEach(ClientsViewMode.allCases) { m in
                        Label(m.label, systemImage: m.icon).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                NavigationLink {
                    AdminTasksInboxView()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "tray.fill").font(.neueCaption2)
                        Text("Tasks").font(.neueCaption2Medium)
                    }
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AVIATheme.timelessBrown)
                    .clipShape(.capsule)
                }
                .buttonStyle(.plain)
            }

            if followUpsDueCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.warning)
                    Text("\(followUpsDueCount) follow-up\(followUpsDueCount == 1 ? "" : "s") due in the next 48h")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                }
                .padding(10)
                .background(AVIATheme.warning.opacity(0.12))
                .clipShape(.rect(cornerRadius: 10))
            }

            statusFilterRow

            if allClients.isEmpty {
                AdminEmptyState(icon: "person.2.slash", title: "No clients found", subtitle: "Clients who sign up will appear here")
            } else if viewMode == .pipeline {
                AdminClientPipelineView(clients: allClients, profiles: crmProfiles)
            } else if filtered.isEmpty {
                AdminEmptyState(icon: "line.3.horizontal.decrease.circle", title: "No clients match", subtitle: "Try a different status filter")
            } else {
                ForEach(filtered, id: \.id) { client in
                    NavigationLink(value: client) {
                        AdminClientCard(
                            client: client,
                            hasBuilds: clientsWithBuildIds.contains(client.id),
                            crmProfile: crmProfiles[client.id]
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task {
            await loadProfiles()
        }
        .refreshable {
            await loadProfiles()
        }
    }

    private var statusFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterPill(label: "All", isSelected: statusFilter == nil) {
                    statusFilter = nil
                }
                ForEach(LeadStatus.allCases) { status in
                    filterPill(label: status.label, icon: status.icon, isSelected: statusFilter == status) {
                        statusFilter = (statusFilter == status) ? nil : status
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0)
    }

    private func filterPill(label: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon { Image(systemName: icon).font(.neueCaption2) }
                Text(label).font(.neueCaption2Medium)
            }
            .foregroundStyle(isSelected ? AVIATheme.aviaWhite : AVIATheme.textPrimary)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background {
                if isSelected { AVIATheme.timelessBrown } else { AVIATheme.cardBackground }
            }
            .clipShape(.capsule)
            .overlay {
                Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: isSelected ? 0 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func loadProfiles() async {
        isLoadingProfiles = true
        let list = await SupabaseService.shared.fetchAllCRMProfiles()
        var map: [String: ClientCRMProfile] = [:]
        for profile in list { map[profile.clientId] = profile }
        crmProfiles = map
        isLoadingProfiles = false
    }
}

struct AdminClientCard: View {
    @Environment(AppViewModel.self) private var viewModel
    let client: ClientUser
    let hasBuilds: Bool
    let crmProfile: ClientCRMProfile?

    private var clientBuilds: [ClientBuild] {
        viewModel.allClientBuilds.filter { $0.hasClient(id: client.id) }
    }

    private var statusColor: Color {
        guard let profile = crmProfile else { return AVIATheme.textTertiary }
        switch profile.leadStatus {
        case .won: return AVIATheme.success
        case .lost: return AVIATheme.textTertiary
        case .negotiation, .proposal, .qualified: return AVIATheme.timelessBrown
        case .contacted: return AVIATheme.timelessBrown.opacity(0.8)
        case .new: return AVIATheme.warning
        }
    }

    private var temperatureColor: Color {
        switch crmProfile?.leadTemperature {
        case .hot: return AVIATheme.warning
        case .cold: return AVIATheme.textSecondary
        default: return AVIATheme.timelessBrown
        }
    }

    var body: some View {
        BentoCard(cornerRadius: 11) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    UserAvatarView(user: client, size: 42, fontSize: 15)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(client.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? client.email : client.fullName)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text(client.email)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        if let profile = crmProfile {
                            HStack(spacing: 4) {
                                Image(systemName: profile.leadStatus.icon)
                                    .font(.neueCaption2)
                                Text(profile.leadStatus.label)
                                    .font(.neueCaption2Medium)
                            }
                            .foregroundStyle(statusColor)
                        }
                        Text("\(clientBuilds.count) build\(clientBuilds.count == 1 ? "" : "s")")
                            .font(.neueCaption2)
                            .foregroundStyle(hasBuilds ? AVIATheme.timelessBrown : AVIATheme.textTertiary)
                    }
                }
                .padding(14)

                if let profile = crmProfile, (!profile.tags.isEmpty || profile.nextFollowUpAt != nil) {
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            Image(systemName: profile.leadTemperature.icon)
                                .font(.neueCaption2)
                            Text(profile.leadTemperature.label)
                                .font(.neueCaption2Medium)
                        }
                        .foregroundStyle(temperatureColor)
                        ForEach(profile.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.textPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(AVIATheme.warmAccent)
                                .clipShape(.capsule)
                        }
                        if profile.tags.count > 2 {
                            Text("+\(profile.tags.count - 2)")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                        Spacer()
                        if let next = profile.nextFollowUpAt {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.neueCaption2)
                                Text(next.formatted(.relative(presentation: .named)))
                                    .font(.neueCaption2)
                            }
                            .foregroundStyle(next < .now ? AVIATheme.warning : AVIATheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }

                if !clientBuilds.isEmpty {
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                    HStack(spacing: 16) {
                        ForEach(clientBuilds.prefix(2)) { build in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(build.overallProgress >= 0.7 ? AVIATheme.success : build.overallProgress > 0 ? AVIATheme.warning : AVIATheme.textTertiary)
                                    .frame(width: 6, height: 6)
                                Text("\(build.homeDesign) · \(Int(build.overallProgress * 100))%")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }

                if !client.phone.isEmpty {
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                    HStack(spacing: 16) {
                        if let phoneURL = URL(string: "tel:\(client.phone.replacingOccurrences(of: " ", with: ""))") {
                            Link(destination: phoneURL) {
                                HStack(spacing: 6) {
                                    Image(systemName: "phone.fill").font(.neueCorp(10))
                                    Text("Call").font(.neueCaption2Medium)
                                }
                                .foregroundStyle(AVIATheme.timelessBrown)
                            }
                        }
                        if let emailURL = URL(string: "mailto:\(client.email)") {
                            Link(destination: emailURL) {
                                HStack(spacing: 6) {
                                    Image(systemName: "envelope.fill").font(.neueCorp(10))
                                    Text("Email").font(.neueCaption2Medium)
                                }
                                .foregroundStyle(AVIATheme.timelessBrown)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            }
        }
    }
}
