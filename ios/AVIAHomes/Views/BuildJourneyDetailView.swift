import SwiftUI

struct BuildJourneyDetailView: View {
    @Environment(CustomerJourneyViewModel.self) private var journeyVM
    @Environment(SpecificationViewModel.self) private var specVM
    @Environment(ColourSelectionViewModel.self) private var colourVM
    @Environment(\.dismiss) private var dismiss
    let onNavigateToSpecs: () -> Void
    let onNavigateToColours: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    overallProgressCard
                    stagesTimeline
                    currentStageDetail
                    if journeyVM.currentStage == .complete {
                        completionBanner
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(AVIATheme.background)
            .navigationTitle("Your Build Journey")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.teal)
                }
            }
        }
    }

    private var overallProgressCard: some View {
        BentoCard(cornerRadius: 20) {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(AVIATheme.teal.opacity(0.12), lineWidth: 6)
                        Circle()
                            .trim(from: 0, to: journeyVM.stageProgress)
                            .stroke(AVIATheme.teal, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.6), value: journeyVM.stageProgress)
                        VStack(spacing: 0) {
                            Text("\(Int(journeyVM.stageProgress * 100))")
                                .font(.neueCorpMedium(28))
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text("%")
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                    }
                    .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Selection Progress")
                            .font(.neueCorpMedium(20))
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text(journeyVM.currentStage.subtitle)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Spacer()
                }

                HStack(spacing: 12) {
                    statPill(
                        value: journeyVM.currentStage == .specifications ? "In Progress" : "Complete",
                        label: "Specs",
                        color: journeyVM.specsConfirmed ? AVIATheme.success : AVIATheme.warning
                    )
                    statPill(
                        value: colourVM.isSubmitted ? "Submitted" : "\(colourVM.completedCount)/\(colourVM.totalCount)",
                        label: "Colours",
                        color: colourVM.isSubmitted ? AVIATheme.success : (journeyVM.specsConfirmed ? AVIATheme.warning : AVIATheme.textTertiary)
                    )
                }
            }
            .padding(18)
        }
    }

    private func statPill(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.neueCaptionMedium)
                .foregroundStyle(color)
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AVIATheme.surfaceElevated)
        .clipShape(.rect(cornerRadius: 12))
    }

    private var stagesTimeline: some View {
        VStack(spacing: 0) {
            ForEach(JourneyStage.allCases) { stage in
                let isCompleted = stage.rawValue < journeyVM.currentStage.rawValue
                let isCurrent = stage == journeyVM.currentStage
                let isLocked = stage.rawValue > journeyVM.currentStage.rawValue

                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        ZStack {
                            if isCompleted {
                                Circle()
                                    .fill(AVIATheme.teal)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "checkmark")
                                    .font(.neueCorpMedium(12))
                                    .foregroundStyle(.white)
                            } else if isCurrent {
                                Circle()
                                    .fill(AVIATheme.teal.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Circle()
                                    .fill(AVIATheme.teal)
                                    .frame(width: 14, height: 14)
                            } else {
                                Circle()
                                    .fill(AVIATheme.surfaceElevated)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "lock.fill")
                                    .font(.neueCorp(10))
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }
                        }

                        if stage != JourneyStage.allCases.last {
                            Rectangle()
                                .fill(isCompleted ? AVIATheme.teal : AVIATheme.surfaceBorder)
                                .frame(width: 2)
                                .frame(minHeight: 40)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(stage.title)
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(isLocked ? AVIATheme.textTertiary : AVIATheme.textPrimary)
                            if isCurrent {
                                Text("CURRENT")
                                    .font(.neueCorpMedium(8))
                                    .kerning(0.6)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AVIATheme.teal)
                                    .clipShape(Capsule())
                            }
                        }
                        Text(stage.subtitle)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                        if isLocked && stage == .colourSelection {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .font(.neueCorp(9))
                                Text("Complete specifications to unlock")
                                    .font(.neueCaption2)
                            }
                            .foregroundStyle(AVIATheme.textTertiary)
                            .padding(.top, 2)
                        }
                    }
                    .padding(.bottom, stage != JourneyStage.allCases.last ? 16 : 0)

                    Spacer()
                }
            }
        }
        .padding(18)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 20))
    }

    private var currentStageDetail: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: journeyVM.currentStage.icon)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.teal)
                Text("What You Need To Do")
                    .font(.neueCorpMedium(18))
                    .foregroundStyle(AVIATheme.textPrimary)
            }

            let tasks = journeyVM.tasksForCurrentStage(specVM: specVM, colourVM: colourVM)
            ForEach(tasks) { task in
                HStack(spacing: 12) {
                    Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.neueCorpMedium(18))
                        .foregroundStyle(task.isComplete ? AVIATheme.success : AVIATheme.surfaceBorder)
                    Text(task.title)
                        .font(.neueSubheadline)
                        .foregroundStyle(task.isComplete ? AVIATheme.textTertiary : AVIATheme.textPrimary)
                        .strikethrough(task.isComplete, color: AVIATheme.textTertiary)
                    Spacer()
                }
                .padding(14)
                .background(task.isComplete ? AVIATheme.success.opacity(0.04) : AVIATheme.cardBackground)
                .clipShape(.rect(cornerRadius: 14))
            }

            if journeyVM.currentStage != .complete {
                Button {
                    switch journeyVM.currentStage {
                    case .specifications:
                        onNavigateToSpecs()
                        dismiss()
                    case .colourSelection:
                        onNavigateToColours()
                        dismiss()
                    case .complete:
                        break
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(journeyVM.currentStage.actionLabel)
                            .font(.neueSubheadlineMedium)
                        Image(systemName: "arrow.right")
                            .font(.neueCorp(12))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AVIATheme.tealGradient)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .padding(.top, 4)
            }
        }
    }

    private var completionBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.neueCorpMedium(40))
                .foregroundStyle(AVIATheme.success)

            Text("All Selections Complete")
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.textPrimary)

            Text("Your specifications and colour selections have been confirmed. Your build coordinator will be in touch with any updates.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AVIATheme.success.opacity(0.06))
        .clipShape(.rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(AVIATheme.success.opacity(0.15), lineWidth: 1)
        }
    }
}
