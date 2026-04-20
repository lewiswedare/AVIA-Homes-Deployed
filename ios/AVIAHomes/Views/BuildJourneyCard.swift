import SwiftUI

struct BuildJourneyCard: View {
    @Environment(CustomerJourneyViewModel.self) private var journeyVM
    @Environment(SpecificationViewModel.self) private var specVM
    @Environment(ColourSelectionViewModel.self) private var colourVM
    let onTapAction: () -> Void
    let onNavigateToSpecs: () -> Void
    let onNavigateToColours: () -> Void

    var body: some View {
        Button(action: onTapAction) {
            VStack(spacing: 0) {
                headerSection
                Divider().overlay(AVIATheme.surfaceBorder)
                stageIndicator
                Divider().overlay(AVIATheme.surfaceBorder)
                tasksList
                actionButton
            }
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.pressable(.subtle))
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(AVIATheme.timelessBrown.opacity(0.15), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: journeyVM.stageProgress)
                    .stroke(AVIATheme.timelessBrown, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: journeyVM.stageProgress)
                Image(systemName: journeyVM.currentStage.icon)
                    .font(.neueCorpMedium(16))
                    .foregroundStyle(AVIATheme.timelessBrown)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("YOUR JOURNEY")
                        .font(.neueCaption2Medium)
                        .kerning(1)
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Spacer()
                    Text("Step \(journeyVM.currentStage.rawValue + 1) of \(JourneyStage.allCases.count)")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                Text(journeyVM.currentStage.title)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
            }
        }
        .padding(16)
    }

    private var stageIndicator: some View {
        HStack(spacing: 0) {
            ForEach(JourneyStage.allCases) { stage in
                let isCurrent = stage == journeyVM.currentStage
                let isCompleted = stage.rawValue < journeyVM.currentStage.rawValue

                HStack(spacing: 0) {
                    VStack(spacing: 6) {
                        ZStack {
                            if isCompleted {
                                Circle()
                                    .fill(AVIATheme.timelessBrown)
                                    .frame(width: 24, height: 24)
                                Image(systemName: "checkmark")
                                    .font(.neueCorpMedium(10))
                                    .foregroundStyle(AVIATheme.aviaWhite)
                            } else if isCurrent {
                                Circle()
                                    .fill(AVIATheme.timelessBrown.opacity(0.15))
                                    .frame(width: 24, height: 24)
                                Circle()
                                    .fill(AVIATheme.timelessBrown)
                                    .frame(width: 10, height: 10)
                            } else {
                                Circle()
                                    .fill(AVIATheme.surfaceElevated)
                                    .frame(width: 24, height: 24)
                            }
                        }

                        Text(stage.title)
                            .font(.neueCorpMedium(9))
                            .foregroundStyle(isCurrent ? AVIATheme.textPrimary : AVIATheme.textTertiary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(width: 80)
                    }

                    if stage != JourneyStage.allCases.last {
                        Rectangle()
                            .fill(isCompleted ? AVIATheme.timelessBrown : AVIATheme.surfaceBorder)
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .padding(.bottom, 28)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var tasksList: some View {
        let tasks = journeyVM.tasksForCurrentStage(specVM: specVM, colourVM: colourVM)
        return VStack(spacing: 0) {
            ForEach(tasks) { task in
                HStack(spacing: 10) {
                    Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.neueCorp(14))
                        .foregroundStyle(task.isComplete ? AVIATheme.success : AVIATheme.textTertiary)
                    Text(task.title)
                        .font(.neueCaption)
                        .foregroundStyle(task.isComplete ? AVIATheme.textSecondary : AVIATheme.textPrimary)
                        .strikethrough(task.isComplete, color: AVIATheme.textTertiary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 4)
    }

    private var actionButton: some View {
        Button {
            switch journeyVM.currentStage {
            case .specifications:
                onNavigateToSpecs()
            case .colourSelection:
                onNavigateToColours()
            case .complete:
                onTapAction()
            }
        } label: {
            HStack(spacing: 8) {
                Text(journeyVM.currentStage.actionLabel)
                    .font(.neueSubheadlineMedium)
                Image(systemName: "arrow.right")
                    .font(.neueCorp(12))
            }
            .foregroundStyle(AVIATheme.aviaWhite)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(AVIATheme.primaryGradient)
            .clipShape(.rect(cornerRadius: 12))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 4)
    }
}
