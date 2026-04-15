import SwiftUI

struct ClientBuildTimelineView: View {
    @Environment(AppViewModel.self) private var viewModel
    let build: ClientBuild

    @State private var milestones: [BuildMilestone] = []
    @State private var expandedStage: String?
    @State private var isLoading = true

    private var progress: Double { build.overallProgress }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                progressHeader
                nextMilestoneCard
                actionRequiredSection
                timelineSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .task {
            milestones = await SupabaseService.shared.fetchMilestonesForBuild(buildId: build.id)
            isLoading = false
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        BentoCard(cornerRadius: 18) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(progress * 100))%")
                            .font(.neueCorpMedium(38))
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("Overall Completion")
                            .font(.neueSubheadline)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        if let stage = build.currentStage {
                            Text("CURRENT STAGE")
                                .font(.neueCorpMedium(9))
                                .kerning(1.5)
                                .foregroundStyle(AVIATheme.textTertiary)
                            Text(stage.name)
                                .font(.neueHeadline)
                                .foregroundStyle(AVIATheme.teal)
                        }
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AVIATheme.teal.opacity(0.1)).frame(height: 8)
                        Capsule().fill(AVIATheme.tealGradient).frame(width: max(0, geo.size.width * progress), height: 8)
                    }
                }
                .frame(height: 8)

                if let start = build.estimatedStartDate, let end = build.estimatedCompletionDate {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Est. Start")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                            Text(start.formatted(.dateTime.month(.abbreviated).day().year()))
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Est. Completion")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                            Text(end.formatted(.dateTime.month(.abbreviated).day().year()))
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Next Milestone

    @ViewBuilder
    private var nextMilestoneCard: some View {
        let upcoming = milestones.first { $0.status != .completed }
        if let next = upcoming {
            BentoCard(cornerRadius: 16) {
                HStack(spacing: 14) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AVIATheme.teal)
                        .frame(width: 44, height: 44)
                        .background(AVIATheme.teal.opacity(0.1))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("NEXT MILESTONE")
                            .font(.neueCorpMedium(9))
                            .kerning(1.0)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text(next.title)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        if let due = next.dueDate {
                            Text(due.formatted(.dateTime.month(.abbreviated).day().year()))
                                .font(.neueCaption)
                                .foregroundStyle(next.isOverdue ? AVIATheme.destructive : AVIATheme.textSecondary)
                        }
                    }

                    Spacer()

                    if next.requiresClientAction {
                        Text("ACTION\nREQUIRED")
                            .font(.neueCorpMedium(8))
                            .kerning(0.3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(AVIATheme.warning)
                            .clipShape(.rect(cornerRadius: 8))
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Action Required

    @ViewBuilder
    private var actionRequiredSection: some View {
        let actionItems = milestones.filter { $0.isActionRequired }
        if !actionItems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(AVIATheme.warning)
                    Text("Action Required")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    StatusBadge(title: "\(actionItems.count)", color: AVIATheme.warning)
                }

                ForEach(actionItems) { item in
                    BentoCard(cornerRadius: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(AVIATheme.warning)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                if let desc = item.clientActionDescription {
                                    Text(desc)
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textSecondary)
                                }
                                if let due = item.dueDate {
                                    Text("Due: \(due.formatted(.dateTime.month(.abbreviated).day().year()))")
                                        .font(.neueCaption2)
                                        .foregroundStyle(item.isOverdue ? AVIATheme.destructive : AVIATheme.textTertiary)
                                }
                            }

                            Spacer()
                        }
                        .padding(14)
                    }
                }
            }
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(build.buildStages.enumerated()), id: \.element.id) { index, stage in
                let stageMilestones = milestones.filter { $0.buildStageId == stage.id }
                let isExpanded = expandedStage == stage.id

                ClientTimelineStageRow(
                    stage: stage,
                    milestones: stageMilestones,
                    isFirst: index == 0,
                    isLast: index == build.buildStages.count - 1,
                    isExpanded: isExpanded
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        expandedStage = isExpanded ? nil : stage.id
                    }
                }
            }
        }
    }
}

// MARK: - Client Timeline Stage Row

struct ClientTimelineStageRow: View {
    let stage: BuildStage
    let milestones: [BuildMilestone]
    let isFirst: Bool
    let isLast: Bool
    let isExpanded: Bool
    let action: () -> Void

    private var statusColor: Color {
        switch stage.status {
        case .completed: AVIATheme.success
        case .inProgress: AVIATheme.teal
        case .upcoming: AVIATheme.textTertiary
        case .delayed: AVIATheme.destructive
        }
    }

    private var actionCount: Int {
        milestones.filter { $0.isActionRequired }.count
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline indicator
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle()
                        .fill(stage.status == .upcoming ? AVIATheme.surfaceBorder : AVIATheme.teal.opacity(0.3))
                        .frame(width: 2, height: 16)
                } else {
                    Color.clear.frame(width: 2, height: 16)
                }

                ZStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 28, height: 28)

                    switch stage.status {
                    case .completed:
                        Image(systemName: "checkmark")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(.white)
                    case .inProgress:
                        Circle().fill(.white).frame(width: 10, height: 10)
                    case .upcoming:
                        Circle().fill(.white.opacity(0.5)).frame(width: 10, height: 10)
                    case .delayed:
                        Image(systemName: "exclamationmark")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(.white)
                    }
                }

                if !isLast {
                    Rectangle()
                        .fill(stage.status == .completed ? AVIATheme.teal.opacity(0.3) : AVIATheme.surfaceBorder)
                        .frame(width: 2)
                        .frame(minHeight: isExpanded ? 160 : 40)
                }
            }
            .frame(width: 28)

            // Content
            Button(action: action) {
                BentoCard(cornerRadius: 14) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(stage.name)
                                        .font(.neueSubheadlineMedium)
                                        .foregroundStyle(stage.status == .upcoming ? AVIATheme.textTertiary : AVIATheme.textPrimary)
                                    if actionCount > 0 {
                                        Text("\(actionCount)")
                                            .font(.neueCorpMedium(8))
                                            .foregroundStyle(.white)
                                            .frame(width: 18, height: 18)
                                            .background(AVIATheme.warning)
                                            .clipShape(Circle())
                                    }
                                }
                                Text(stage.description)
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            Spacer()
                            if stage.status == .inProgress {
                                StatusBadge(title: "\(Int(stage.progress * 100))%", color: AVIATheme.teal)
                            } else if stage.status == .delayed {
                                StatusBadge(title: "Delayed", color: AVIATheme.destructive)
                            }
                            Image(systemName: "chevron.down")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }

                        if isExpanded {
                            expandedContent
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(14)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .padding(.bottom, isLast ? 0 : 4)
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if stage.status == .inProgress {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AVIATheme.teal.opacity(0.1)).frame(height: 4)
                        Capsule().fill(AVIATheme.tealGradient).frame(width: max(0, geo.size.width * stage.progress), height: 4)
                    }
                }
                .frame(height: 4)
            }

            if let start = stage.estimatedStartDate {
                HStack(spacing: 8) {
                    Image(systemName: "calendar").font(.neueCaption).foregroundStyle(AVIATheme.textTertiary)
                    Text("Est. Start: \(start.formatted(date: .abbreviated, time: .omitted))")
                        .font(.neueCaption).foregroundStyle(AVIATheme.textSecondary)
                }
            }

            if let end = stage.estimatedEndDate {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock").font(.neueCaption).foregroundStyle(AVIATheme.textTertiary)
                    Text("Est. End: \(end.formatted(date: .abbreviated, time: .omitted))")
                        .font(.neueCaption).foregroundStyle(AVIATheme.textSecondary)
                }
            }

            if let start = stage.actualStartDate {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle").font(.neueCaption).foregroundStyle(AVIATheme.teal)
                    Text("Started: \(start.formatted(date: .abbreviated, time: .omitted))")
                        .font(.neueCaption).foregroundStyle(AVIATheme.textSecondary)
                }
            }

            if let end = stage.actualEndDate {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle").font(.neueCaption).foregroundStyle(AVIATheme.success)
                    Text("Completed: \(end.formatted(date: .abbreviated, time: .omitted))")
                        .font(.neueCaption).foregroundStyle(AVIATheme.textSecondary)
                }
            }

            if let notes = stage.notes {
                Text(notes)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AVIATheme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: 10))
            }

            // Milestones within this stage
            if !milestones.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MILESTONES")
                        .font(.neueCaption2Medium)
                        .kerning(0.5)
                        .foregroundStyle(AVIATheme.textTertiary)

                    ForEach(milestones) { milestone in
                        HStack(spacing: 10) {
                            Image(systemName: milestone.status == .completed ? "checkmark.circle.fill" : milestone.isOverdue ? "exclamationmark.circle.fill" : "circle")
                                .font(.system(size: 14))
                                .foregroundStyle(milestone.status == .completed ? AVIATheme.success : milestone.isOverdue ? AVIATheme.destructive : AVIATheme.textTertiary)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(milestone.title)
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(milestone.status == .completed ? AVIATheme.textTertiary : AVIATheme.textPrimary)
                                        .strikethrough(milestone.status == .completed)
                                    if milestone.requiresClientAction && milestone.status != .completed {
                                        Image(systemName: "hand.raised.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(AVIATheme.warning)
                                    }
                                }
                                if let due = milestone.dueDate {
                                    Text(due.formatted(.dateTime.month(.abbreviated).day()))
                                        .font(.neueCaption2)
                                        .foregroundStyle(milestone.isOverdue ? AVIATheme.destructive : AVIATheme.textTertiary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}
