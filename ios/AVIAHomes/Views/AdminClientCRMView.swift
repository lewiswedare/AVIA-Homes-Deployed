import SwiftUI

struct AdminClientCRMView: View {
    @Environment(AppViewModel.self) private var viewModel
    let client: ClientUser

    @State private var activities: [ClientActivity] = []
    @State private var isLoading: Bool = true
    @State private var pushedConversation: Conversation?
    @State private var selectedFilter: ActivityFilter = .all

    enum ActivityFilter: String, CaseIterable, Identifiable {
        case all, designs, floorplans, specs, enquiries
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "All"
            case .designs: return "Designs"
            case .floorplans: return "Plans"
            case .specs: return "Specs"
            case .enquiries: return "Enquiries"
            }
        }
        func matches(_ kind: ClientActivityKind) -> Bool {
            switch self {
            case .all: return true
            case .designs: return kind == .designView
            case .floorplans: return kind == .floorplanDownload
            case .specs: return kind == .specRangeView
            case .enquiries: return kind == .enquirySent
            }
        }
    }

    private var clientBuilds: [ClientBuild] {
        viewModel.allClientBuilds.filter { $0.hasClient(id: client.id) }
    }

    private var filteredActivities: [ClientActivity] {
        activities.filter { selectedFilter.matches($0.kind) }
    }

    private var designViews: [ClientActivity] { activities.filter { $0.kind == .designView } }
    private var floorplanDownloads: [ClientActivity] { activities.filter { $0.kind == .floorplanDownload } }
    private var specViews: [ClientActivity] { activities.filter { $0.kind == .specRangeView } }
    private var enquiries: [ClientActivity] { activities.filter { $0.kind == .enquirySent } }

    private var topDesigns: [(name: String, count: Int)] {
        topItems(from: designViews, limit: 3)
    }

    private var topSpecs: [(name: String, count: Int)] {
        topItems(from: specViews, limit: 3)
    }

    private func topItems(from list: [ClientActivity], limit: Int) -> [(name: String, count: Int)] {
        let grouped = Dictionary(grouping: list, by: \.referenceName)
        return grouped
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(limit)
            .map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileHeader
                quickActions
                metricsGrid
                if !topDesigns.isEmpty || !topSpecs.isEmpty {
                    interestsSection
                }
                lastSeenCard
                activityTimeline
            }
            .padding(16)
        }
        .background(AVIATheme.background)
        .navigationTitle("Client CRM")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $pushedConversation) { conversation in
            ChatView(conversation: conversation)
        }
        .task {
            await loadActivity()
        }
        .refreshable {
            await loadActivity()
        }
    }

    private func loadActivity() async {
        isLoading = true
        let result = await SupabaseService.shared.fetchClientActivity(clientId: client.id, limit: 300)
        activities = result
        isLoading = false
    }

    private var profileHeader: some View {
        BentoCard(cornerRadius: 14) {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    Text(client.initials.isEmpty ? "?" : client.initials)
                        .font(.neueCorpMedium(22))
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(width: 64, height: 64)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(client.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? client.email : client.fullName)
                            .font(.neueCorpMedium(20))
                            .foregroundStyle(AVIATheme.textPrimary)
                            .lineLimit(2)
                        Text(client.email)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(1)
                        if !client.phone.isEmpty {
                            Text(client.phone)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                    }
                    Spacer()
                }

                if !clientBuilds.isEmpty {
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ACTIVE BUILDS")
                            .font(.neueCaption2Medium)
                            .tracking(1.0)
                            .foregroundStyle(AVIATheme.textTertiary)
                        ForEach(clientBuilds) { build in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(build.overallProgress >= 0.7 ? AVIATheme.success : build.overallProgress > 0 ? AVIATheme.warning : AVIATheme.textTertiary)
                                    .frame(width: 6, height: 6)
                                Text(build.homeDesign)
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Spacer()
                                Text("\(Int(build.overallProgress * 100))%")
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            Button {
                Task { await openConversation() }
            } label: {
                quickActionLabel(icon: "bubble.left.and.bubble.right.fill", label: "Message")
            }
            if !client.phone.isEmpty,
               let phoneURL = URL(string: "tel:\(client.phone.replacingOccurrences(of: " ", with: ""))") {
                Link(destination: phoneURL) {
                    quickActionLabel(icon: "phone.fill", label: "Call")
                }
            }
            if let emailURL = URL(string: "mailto:\(client.email)") {
                Link(destination: emailURL) {
                    quickActionLabel(icon: "envelope.fill", label: "Email")
                }
            }
        }
    }

    private func quickActionLabel(icon: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.aviaWhite)
                .frame(width: 38, height: 38)
                .background(AVIATheme.primaryGradient)
                .clipShape(Circle())
            Text(label)
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).stroke(AVIATheme.surfaceBorder, lineWidth: 1)
        }
    }

    private func openConversation() async {
        let convId = await viewModel.messagingService.getOrCreateConversation(
            currentUserId: viewModel.currentUser.id,
            otherUserId: client.id
        )
        if let conv = viewModel.messagingService.conversations.first(where: { $0.id == convId }) {
            pushedConversation = conv
        }
    }

    private var metricsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                AdminMetricCard(value: "\(designViews.count)", label: "Design Views", icon: "house.fill", color: AVIATheme.timelessBrown)
                AdminMetricCard(value: "\(floorplanDownloads.count)", label: "Floorplans", icon: "arrow.down.doc.fill", color: AVIATheme.success)
            }
            HStack(spacing: 10) {
                AdminMetricCard(value: "\(specViews.count)", label: "Spec Views", icon: "square.stack.3d.up.fill", color: AVIATheme.warning)
                AdminMetricCard(value: "\(enquiries.count)", label: "Enquiries", icon: "paperplane.fill", color: AVIATheme.timelessBrown)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var interestsSection: some View {
        BentoCard(cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 14) {
                Text("TOP INTERESTS")
                    .font(.neueCaption2Medium)
                    .tracking(1.2)
                    .foregroundStyle(AVIATheme.textTertiary)

                if !topDesigns.isEmpty {
                    interestList(title: "Designs", icon: "house.fill", items: topDesigns)
                }
                if !topSpecs.isEmpty {
                    if !topDesigns.isEmpty {
                        Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                    }
                    interestList(title: "Spec Ranges", icon: "square.stack.3d.up.fill", items: topSpecs)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func interestList(title: String, icon: String, items: [(name: String, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.timelessBrown)
                Text(title)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
            }
            ForEach(items, id: \.name) { item in
                HStack {
                    Text(item.name)
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    Text("\(item.count) view\(item.count == 1 ? "" : "s")")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AVIATheme.warmAccent)
                        .clipShape(.capsule)
                }
            }
        }
    }

    private var lastSeenCard: some View {
        BentoCard(cornerRadius: 12) {
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 32, height: 32)
                    .background(AVIATheme.timelessBrown)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last Activity")
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textTertiary)
                    if let last = activities.first {
                        Text("\(last.kind.label) · \(last.referenceName)")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                            .lineLimit(1)
                        Text(last.createdAt.formatted(.relative(presentation: .named)))
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    } else if isLoading {
                        Text("Loading…")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    } else {
                        Text("No activity tracked yet")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                }
                Spacer()
            }
            .padding(14)
        }
    }

    private var activityTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ACTIVITY TIMELINE")
                    .font(.neueCaption2Medium)
                    .tracking(1.2)
                    .foregroundStyle(AVIATheme.textTertiary)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ActivityFilter.allCases) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(filter.label)
                                .font(.neueCaption2Medium)
                                .foregroundStyle(selectedFilter == filter ? AVIATheme.aviaWhite : AVIATheme.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background {
                                    if selectedFilter == filter {
                                        AVIATheme.timelessBrown
                                    } else {
                                        AVIATheme.cardBackground
                                    }
                                }
                                .clipShape(.capsule)
                                .overlay {
                                    Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: selectedFilter == filter ? 0 : 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)

            if isLoading && activities.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
            } else if filteredActivities.isEmpty {
                AdminEmptyState(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "No activity yet",
                    subtitle: "Client engagement will appear here as they explore the app"
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filteredActivities.enumerated()), id: \.element.id) { index, activity in
                        ActivityTimelineRow(activity: activity, isLast: index == filteredActivities.count - 1)
                    }
                }
                .padding(14)
                .background(AVIATheme.cardBackground)
                .clipShape(.rect(cornerRadius: 13))
                .overlay {
                    RoundedRectangle(cornerRadius: 13).stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                }
            }
        }
    }
}

private struct ActivityTimelineRow: View {
    let activity: ClientActivity
    let isLast: Bool

    private var iconColor: Color {
        switch activity.kind {
        case .designView: return AVIATheme.timelessBrown
        case .floorplanDownload: return AVIATheme.success
        case .specRangeView: return AVIATheme.warning
        case .packageView: return AVIATheme.timelessBrown
        case .enquirySent: return AVIATheme.timelessBrown
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: activity.kind.icon)
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 28, height: 28)
                    .background(iconColor)
                    .clipShape(Circle())
                if !isLast {
                    Rectangle()
                        .fill(AVIATheme.surfaceBorder)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(activity.kind.label)
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textTertiary)
                Text(activity.referenceName)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(activity.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            .padding(.bottom, isLast ? 0 : 14)

            Spacer()
        }
    }
}
