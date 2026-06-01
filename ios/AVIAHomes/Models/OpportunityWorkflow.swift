import Foundation

/// A single manual checklist step in the opportunity sales workflow.
struct OpportunityStep: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let icon: String
}

/// Defines the sales workflow an opportunity moves through before it can become a
/// client. Unlike `LifecycleStageGuide` (which auto-detects progress from a
/// registered client's activity), opportunities are pre-account contacts, so the
/// team ticks each step off manually as they progress the deal.
enum OpportunityWorkflow {
    /// Ordered pipeline stages an opportunity moves through. `won` is terminal
    /// (the contact has become a client).
    static let stages: [LeadStatus] = [.qualified, .proposal, .negotiation]

    /// Requirement id that gates client conversion — a build contract must be
    /// allocated before an opportunity becomes a client.
    static let contractStepID = "negotiation.contract"

    /// Maps any incoming status into a valid workflow stage.
    static func normalizedStage(_ status: LeadStatus) -> LeadStatus {
        switch status {
        case .new, .contacted, .qualified: return .qualified
        case .proposal: return .proposal
        case .negotiation: return .negotiation
        case .won: return .negotiation
        case .lost: return .qualified
        }
    }

    static func nextStage(after status: LeadStatus) -> LeadStatus? {
        let stage = normalizedStage(status)
        guard let idx = stages.firstIndex(of: stage), idx + 1 < stages.count else { return nil }
        return stages[idx + 1]
    }

    static func previousStage(before status: LeadStatus) -> LeadStatus? {
        let stage = normalizedStage(status)
        guard let idx = stages.firstIndex(of: stage), idx > 0 else { return nil }
        return stages[idx - 1]
    }

    static func steps(for status: LeadStatus) -> [OpportunityStep] {
        switch normalizedStage(status) {
        case .qualified:
            return [
                OpportunityStep(id: "qualified.discovery", title: "Discovery call completed", detail: "Understand their goals, site, and motivation.", icon: "bubble.left.and.bubble.right.fill"),
                OpportunityStep(id: "qualified.budget", title: "Budget & timeline confirmed", detail: "Qualify affordability and when they want to build.", icon: "dollarsign.circle.fill"),
                OpportunityStep(id: "qualified.designs", title: "Preferred designs shortlisted", detail: "Agree on the designs or range they love.", icon: "house.fill")
            ]
        case .proposal:
            return [
                OpportunityStep(id: "proposal.sent", title: "Tailored proposal sent", detail: "Deliver pricing and inclusions for their selection.", icon: "doc.text.fill"),
                OpportunityStep(id: "proposal.pack", title: "Floorplan & spec pack shared", detail: "Send the full plan and specification documents.", icon: "arrow.down.doc.fill"),
                OpportunityStep(id: "proposal.meeting", title: "Review meeting booked", detail: "Schedule a walkthrough of the proposal together.", icon: "calendar.badge.plus")
            ]
        case .negotiation:
            return [
                OpportunityStep(id: "negotiation.terms", title: "Terms & inclusions agreed", detail: "Lock scope, price, and any variations.", icon: "checkmark.seal.fill"),
                OpportunityStep(id: "negotiation.deposit", title: "Deposit / EOI received", detail: "Confirm commitment with an initial payment.", icon: "creditcard.fill"),
                OpportunityStep(id: contractStepID, title: "Build contract allocated", detail: "Allocate the build contract — this converts them to a client.", icon: "signature")
            ]
        default:
            return []
        }
    }
}
