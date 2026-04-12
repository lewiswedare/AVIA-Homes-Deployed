import SwiftUI

@Observable
class CustomerJourneyViewModel {
    var specsConfirmed: Bool = false
    var coloursUnlocked: Bool = false

    var currentStage: JourneyStage {
        if specsConfirmed && coloursUnlocked {
            return .complete
        } else if specsConfirmed {
            return .colourSelection
        }
        return .specifications
    }

    var stageProgress: Double {
        Double(currentStage.rawValue) / Double(JourneyStage.allCases.count - 1)
    }

    func tasksForCurrentStage(specVM: SpecificationViewModel, colourVM: ColourSelectionViewModel) -> [JourneyTask] {
        switch currentStage {
        case .specifications:
            let hasReviewedSpecs = true
            let pendingUpgrades = specVM.upgradeRequests.filter { $0.status == .pending }
            let allUpgradesResolved = pendingUpgrades.isEmpty
            return [
                JourneyTask(id: "review_specs", title: "Review your \(specVM.currentTier.rawValue) inclusions", icon: "checkmark.circle.fill", isComplete: hasReviewedSpecs),
                JourneyTask(id: "upgrades_resolved", title: "Confirm or resolve upgrade requests", icon: pendingUpgrades.isEmpty ? "checkmark.circle.fill" : "clock.fill", isComplete: allUpgradesResolved),
                JourneyTask(id: "confirm_specs", title: "Confirm your specifications", icon: specsConfirmed ? "checkmark.circle.fill" : "circle", isComplete: specsConfirmed),
            ]
        case .colourSelection:
            let allSelected = colourVM.isComplete
            let submitted = colourVM.isSubmitted
            return [
                JourneyTask(id: "select_colours", title: "Complete all colour selections (\(colourVM.completedCount)/\(colourVM.totalCount))", icon: allSelected ? "checkmark.circle.fill" : "circle", isComplete: allSelected),
                JourneyTask(id: "submit_colours", title: "Review and submit selections", icon: submitted ? "checkmark.circle.fill" : "circle", isComplete: submitted),
            ]
        case .complete:
            return [
                JourneyTask(id: "specs_done", title: "Specifications confirmed", icon: "checkmark.circle.fill", isComplete: true),
                JourneyTask(id: "colours_done", title: "Colour selections submitted", icon: "checkmark.circle.fill", isComplete: true),
            ]
        }
    }

    func confirmSpecifications() {
        specsConfirmed = true
        coloursUnlocked = true
    }

    func markColoursComplete() {
        if specsConfirmed {
            coloursUnlocked = true
        }
    }
}
