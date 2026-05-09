import SwiftUI

@Observable
class CustomerJourneyViewModel {
    var specsConfirmed: Bool = false
    var coloursUnlocked: Bool = false

    var currentStage: JourneyStage {
        if specsConfirmed && coloursUnlocked {
            return .complete
        }
        return .selections
    }

    var stageProgress: Double {
        Double(currentStage.rawValue) / Double(max(1, JourneyStage.allCases.count - 1))
    }

    func tasksForCurrentStage(specVM: SpecificationViewModel, colourVM: ColourSelectionViewModel) -> [JourneyTask] {
        switch currentStage {
        case .selections:
            let pendingUpgrades = specVM.upgradeRequests.filter { $0.status == .pending }
            let allUpgradesResolved = pendingUpgrades.isEmpty
            let coloursDone = colourVM.isComplete
            return [
                JourneyTask(
                    id: "browse_rooms",
                    title: "Browse rooms and pick your upgrades",
                    icon: "checkmark.circle.fill",
                    isComplete: true
                ),
                JourneyTask(
                    id: "upgrades_resolved",
                    title: "Confirm or resolve upgrade requests",
                    icon: allUpgradesResolved ? "checkmark.circle.fill" : "clock.fill",
                    isComplete: allUpgradesResolved
                ),
                JourneyTask(
                    id: "select_colours",
                    title: "Choose colours & finishes (\(colourVM.completedCount)/\(colourVM.totalCount))",
                    icon: coloursDone ? "checkmark.circle.fill" : "circle",
                    isComplete: coloursDone
                ),
                JourneyTask(
                    id: "submit_selections",
                    title: "Submit your selections for review",
                    icon: specsConfirmed ? "checkmark.circle.fill" : "circle",
                    isComplete: specsConfirmed
                ),
            ]
        case .complete:
            return [
                JourneyTask(id: "selections_done", title: "Selections submitted", icon: "checkmark.circle.fill", isComplete: true),
                JourneyTask(id: "colours_done", title: "Colours confirmed", icon: "checkmark.circle.fill", isComplete: true),
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
