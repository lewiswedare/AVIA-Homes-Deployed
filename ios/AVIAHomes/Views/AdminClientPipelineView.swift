import SwiftUI

struct AdminClientPipelineView: View {
    let clients: [ClientUser]
    let profiles: [String: ClientCRMProfile]

    private func column(for status: LeadStatus) -> [ClientUser] {
        clients.filter { (profiles[$0.id]?.leadStatus ?? .new) == status }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(LeadStatus.allCases) { status in
                    columnView(status: status, clients: column(for: status))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .contentMargins(.horizontal, 0)
    }

    private func columnView(status: LeadStatus, clients: [ClientUser]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: status.icon)
                    .font(.neueCaption2)
                Text(status.label.uppercased())
                    .font(.neueCaption2Medium)
                    .tracking(0.8)
                Spacer()
                Text("\(clients.count)")
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .foregroundStyle(AVIATheme.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AVIATheme.warmAccent)
            .clipShape(.rect(cornerRadius: 10))

            if clients.isEmpty {
                Text("No clients")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AVIATheme.cardBackground)
                    .clipShape(.rect(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundStyle(AVIATheme.surfaceBorder)
                    }
            } else {
                VStack(spacing: 8) {
                    ForEach(clients) { client in
                        NavigationLink(value: client) {
                            pipelineCard(client: client, profile: profiles[client.id])
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(width: 230)
    }

    private func pipelineCard(client: ClientUser, profile: ClientCRMProfile?) -> some View {
        BentoCard(cornerRadius: 10) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(client.initials.isEmpty ? "?" : client.initials)
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(width: 28, height: 28)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(client.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? client.email : client.fullName)
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.textPrimary)
                            .lineLimit(1)
                        Text(client.email)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(1)
                    }
                }
                if let profile {
                    HStack(spacing: 6) {
                        Image(systemName: profile.leadTemperature.icon)
                            .font(.neueCaption2)
                            .foregroundStyle(temperatureColor(profile.leadTemperature))
                        if let next = profile.nextFollowUpAt {
                            Text(next.formatted(.relative(presentation: .named)))
                                .font(.neueCaption2)
                                .foregroundStyle(next < .now ? AVIATheme.warning : AVIATheme.textSecondary)
                        }
                        Spacer()
                    }
                    if !profile.tags.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(profile.tags.prefix(2), id: \.self) { tag in
                                Text(tag)
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(AVIATheme.warmAccent)
                                    .clipShape(.capsule)
                            }
                            if profile.tags.count > 2 {
                                Text("+\(profile.tags.count - 2)")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func temperatureColor(_ temp: LeadTemperature) -> Color {
        switch temp {
        case .hot: return AVIATheme.warning
        case .warm: return AVIATheme.timelessBrown
        case .cold: return AVIATheme.textSecondary
        }
    }
}
