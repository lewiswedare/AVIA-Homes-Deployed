import Foundation

nonisolated enum JourneyStage: Int, CaseIterable, Sendable, Identifiable {
    case selections = 0
    case complete = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .selections: "Selections"
        case .complete: "Selections Complete"
        }
    }

    var subtitle: String {
        switch self {
        case .selections: "Choose your upgrades, colours and finishes — room by room"
        case .complete: "All selections confirmed — your build is underway"
        }
    }

    var icon: String {
        switch self {
        case .selections: "square.grid.2x2.fill"
        case .complete: "checkmark.seal.fill"
        }
    }

    var actionLabel: String {
        switch self {
        case .selections: "Open Selections"
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
