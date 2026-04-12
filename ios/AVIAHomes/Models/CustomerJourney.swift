import Foundation

nonisolated enum JourneyStage: Int, CaseIterable, Sendable, Identifiable {
    case specifications = 0
    case colourSelection = 1
    case complete = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .specifications: "Specifications"
        case .colourSelection: "Colour Selection"
        case .complete: "Selections Complete"
        }
    }

    var subtitle: String {
        switch self {
        case .specifications: "Review your inclusions and confirm any upgrades"
        case .colourSelection: "Choose colours and finishes for your new home"
        case .complete: "All selections confirmed — your build is underway"
        }
    }

    var icon: String {
        switch self {
        case .specifications: "list.clipboard.fill"
        case .colourSelection: "paintpalette.fill"
        case .complete: "checkmark.seal.fill"
        }
    }

    var actionLabel: String {
        switch self {
        case .specifications: "Review Specifications"
        case .colourSelection: "Start Colour Selection"
        case .complete: "View Summary"
        }
    }
}

nonisolated struct JourneyTask: Identifiable, Sendable {
    let id: String
    let title: String
    let icon: String
    let isComplete: Bool
}
