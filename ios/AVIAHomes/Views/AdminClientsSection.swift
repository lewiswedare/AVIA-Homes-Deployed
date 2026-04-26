import SwiftUI

struct AdminClientsSection: View {
    @Environment(AppViewModel.self) private var viewModel
    let searchText: String

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

    var body: some View {
        let allClients = clientsList
        let clientsWithBuildIds = Set(viewModel.allClientBuilds.flatMap(\.allClientIds))

        VStack(spacing: 12) {
            HStack(spacing: 12) {
                AdminMetricCard(value: "\(allClients.count)", label: "Total Clients", icon: "person.2.fill", color: AVIATheme.timelessBrown)
                AdminMetricCard(value: "\(allClients.filter { clientsWithBuildIds.contains($0.id) }.count)", label: "With Builds", icon: "building.2.fill", color: AVIATheme.success)
            }
            .fixedSize(horizontal: false, vertical: true)

            if allClients.isEmpty {
                AdminEmptyState(icon: "person.2.slash", title: "No clients found", subtitle: "Clients who sign up will appear here")
            } else {
                ForEach(allClients, id: \.id) { client in
                    AdminClientCard(client: client, hasBuilds: clientsWithBuildIds.contains(client.id))
                }
            }
        }
    }
}

struct AdminClientCard: View {
    @Environment(AppViewModel.self) private var viewModel
    let client: ClientUser
    let hasBuilds: Bool

    private var clientBuilds: [ClientBuild] {
        viewModel.allClientBuilds.filter { $0.hasClient(id: client.id) }
    }

    var body: some View {
        BentoCard(cornerRadius: 11) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text(client.initials.isEmpty ? "?" : client.initials)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(width: 42, height: 42)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(Circle())

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
                        Text("\(clientBuilds.count) build\(clientBuilds.count == 1 ? "" : "s")")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(hasBuilds ? AVIATheme.timelessBrown : AVIATheme.textTertiary)
                        if let firstBuild = clientBuilds.first {
                            Text(firstBuild.homeDesign)
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                    }
                }
                .padding(14)

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
