import SwiftUI

struct AdminActivitySection: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedBuild: ClientBuild?

    private var activityItems: [ActivityItem] {
        var items: [ActivityItem] = []

        for build in viewModel.allClientBuilds {
            items.append(ActivityItem(
                id: "build_\(build.id)",
                icon: "building.2.fill",
                title: "\(build.clientDisplayName) — \(build.homeDesign)",
                subtitle: "Current: \(build.statusLabel) · \(Int(build.overallProgress * 100))%",
                date: build.contractDate,
                color: AVIATheme.timelessBrown
            ))

            for stage in build.buildStages where stage.status == .completed {
                if let date = stage.completionDate {
                    items.append(ActivityItem(
                        id: "stage_\(build.id)_\(stage.id)",
                        icon: "checkmark.circle.fill",
                        title: "\(stage.name) completed",
                        subtitle: "\(build.clientDisplayName) · \(build.homeDesign)",
                        date: date,
                        color: AVIATheme.success
                    ))
                }
            }
        }

        for request in viewModel.requests {
            let color: Color = switch request.status {
            case .open: AVIATheme.warning
            case .inProgress: AVIATheme.timelessBrown
            case .resolved: AVIATheme.success
            }
            items.append(ActivityItem(
                id: "req_\(request.id)",
                icon: request.category.icon,
                title: request.title,
                subtitle: "\(request.status.rawValue) · \(request.category.rawValue)",
                date: request.lastUpdated,
                color: color
            ))
        }

        return items.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 12) {
            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text("Recent Activity")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                    }

                    if activityItems.isEmpty {
                        AdminEmptyState(icon: "clock", title: "No activity yet", subtitle: "Recent actions will appear here")
                    } else {
                        ForEach(activityItems.prefix(20)) { item in
                            Button {
                                handleActivityTap(item)
                            } label: {
                                activityRow(item)
                            }
                            .buttonStyle(.pressable(.subtle))
                        }
                    }
                }
                .padding(16)
            }
        }
        .sheet(item: $selectedBuild) { build in
            AdminBuildEditSheet(build: build)
        }
    }

    private func activityRow(_ item: ActivityItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.neueCorp(11))
                .foregroundStyle(item.color)
                .frame(width: 28, height: 28)
                .background(item.color.opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .lineLimit(1)
            }

            Spacer()

            Text(item.date.formatted(date: .abbreviated, time: .omitted))
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .padding(.vertical, 4)
    }

    private func handleActivityTap(_ item: ActivityItem) {
        let id = item.id
        if id.hasPrefix("build_") {
            let buildId = String(id.dropFirst("build_".count))
            if let build = viewModel.allClientBuilds.first(where: { $0.id == buildId }) {
                selectedBuild = build
            }
        } else if id.hasPrefix("stage_") {
            let parts = id.dropFirst("stage_".count).split(separator: "_", maxSplits: 1)
            if let buildId = parts.first,
               let build = viewModel.allClientBuilds.first(where: { $0.id == String(buildId) }) {
                selectedBuild = build
            }
        } else if id.hasPrefix("req_") {
            // Request taps - no specific navigation needed since admin requests section handles this
        }
    }
}
