import SwiftUI

struct BuildProgressView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var expandedStage: String?

    private var effectiveStages: [BuildStage] {
        if !viewModel.buildStages.isEmpty {
            return viewModel.buildStages
        }
        return viewModel.clientBuildsForCurrentUser.first?.buildStages ?? []
    }

    private var effectiveProgress: Double {
        if !viewModel.buildStages.isEmpty {
            return viewModel.overallProgress
        }
        return viewModel.clientBuildsForCurrentUser.first?.overallProgress ?? 0
    }

    private var effectiveCurrentStage: BuildStage? {
        if !viewModel.buildStages.isEmpty {
            return viewModel.currentBuildStage
        }
        return viewModel.clientBuildsForCurrentUser.first?.currentStage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroImage

                    VStack(spacing: 20) {
                        overallProgress
                        timelineView
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(AVIATheme.background)
        }
    }

    private var heroImage: some View {
        Color(AVIATheme.surfaceElevated)
            .frame(height: 320)
            .overlay {
                Image("progress_hero")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: AVIATheme.background.opacity(0.15), location: 0.25),
                        .init(color: AVIATheme.background.opacity(0.4), location: 0.45),
                        .init(color: AVIATheme.background.opacity(0.7), location: 0.65),
                        .init(color: AVIATheme.background.opacity(0.9), location: 0.8),
                        .init(color: AVIATheme.background, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Build Progress")
                        .font(.neueCorpMedium(28))
                        .foregroundStyle(AVIATheme.textPrimary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .clipped()
    }

    private var overallProgress: some View {
        BentoCard(cornerRadius: 18) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(effectiveProgress * 100))%")
                            .font(.neueCorpMedium(38))
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("Overall Completion")
                            .font(.neueSubheadline)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Spacer()
                    if let stage = effectiveCurrentStage {
                        VStack(alignment: .trailing, spacing: 4) {
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
                        Capsule()
                            .fill(AVIATheme.teal.opacity(0.1))
                            .frame(height: 8)
                        Capsule()
                            .fill(AVIATheme.tealGradient)
                            .frame(width: max(0, geo.size.width * effectiveProgress), height: 8)
                    }
                }
                .frame(height: 8)
            }
            .padding(20)
        }
    }

    private var timelineView: some View {
        VStack(spacing: 0) {
            ForEach(Array(effectiveStages.enumerated()), id: \.element.id) { index, stage in
                TimelineStageRow(
                    stage: stage,
                    isFirst: index == 0,
                    isLast: index == effectiveStages.count - 1,
                    isExpanded: expandedStage == stage.id
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        expandedStage = expandedStage == stage.id ? nil : stage.id
                    }
                }
            }
        }
    }
}

struct TimelineStageRow: View {
    let stage: BuildStage
    let isFirst: Bool
    let isLast: Bool
    let isExpanded: Bool
    let action: () -> Void

    private var statusColor: Color {
        switch stage.status {
        case .completed: AVIATheme.success
        case .inProgress: AVIATheme.teal
        case .upcoming: AVIATheme.textTertiary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            timelineIndicator
            stageContent
        }
    }

    private var timelineIndicator: some View {
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
                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                case .upcoming:
                    Circle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 10, height: 10)
                }
            }

            if !isLast {
                Rectangle()
                    .fill(stage.status == .completed ? AVIATheme.teal.opacity(0.3) : AVIATheme.surfaceBorder)
                    .frame(width: 2)
                    .frame(minHeight: isExpanded ? 140 : 40)
            }
        }
        .frame(width: 28)
    }

    private var stageContent: some View {
        Button(action: action) {
            BentoCard(cornerRadius: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(stage.name)
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(stage.status == .upcoming ? AVIATheme.textTertiary : AVIATheme.textPrimary)
                            Text(stage.description)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                        Spacer()
                        if stage.status == .inProgress {
                            StatusBadge(title: "\(Int(stage.progress * 100))%", color: AVIATheme.teal)
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

            if let start = stage.startDate {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text("Started: \(start.formatted(date: .abbreviated, time: .omitted))")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
            }

            if let completion = stage.completionDate {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.success)
                    Text("Completed: \(completion.formatted(date: .abbreviated, time: .omitted))")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
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

            if stage.photoCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.teal)
                    Text("\(stage.photoCount) photos")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.teal)
                }
            }
        }
    }
}
