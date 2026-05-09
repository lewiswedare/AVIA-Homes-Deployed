import Foundation
import SwiftUI

// MARK: - LeadStatus + Lifecycle ordering

extension LeadStatus {
    /// Ordered pipeline stages (excluding the terminal `lost` branch).
    static let pipeline: [LeadStatus] = [.new, .contacted, .qualified, .proposal, .negotiation, .won]

    /// 1-based position in the pipeline. Returns 0 for `lost`.
    var pipelineIndex: Int {
        Self.pipeline.firstIndex(of: self).map { $0 + 1 } ?? 0
    }

    var nextStage: LeadStatus? {
        guard let idx = Self.pipeline.firstIndex(of: self), idx + 1 < Self.pipeline.count else { return nil }
        return Self.pipeline[idx + 1]
    }

    var previousStage: LeadStatus? {
        guard let idx = Self.pipeline.firstIndex(of: self), idx > 0 else { return nil }
        return Self.pipeline[idx - 1]
    }

    var isTerminal: Bool { self == .won || self == .lost }

    /// Short tagline shown under the current stage in the lifecycle card.
    var lifecycleSubtitle: String {
        switch self {
        case .new: return "Make first contact and introduce AVIA."
        case .contacted: return "Qualify the lead — needs, budget, timeline."
        case .qualified: return "Prepare and present a tailored proposal."
        case .proposal: return "Address feedback and negotiate terms."
        case .negotiation: return "Close the deal and confirm commitment."
        case .won: return "Onboarding — hand over to the build team."
        case .lost: return "Archive with reason and revisit later."
        }
    }

    var stageColor: Color {
        switch self {
        case .new: return AVIATheme.textSecondary
        case .contacted: return AVIATheme.timelessBrown.opacity(0.7)
        case .qualified: return AVIATheme.timelessBrown
        case .proposal: return AVIATheme.warning
        case .negotiation: return AVIATheme.warning.opacity(0.85)
        case .won: return AVIATheme.success
        case .lost: return AVIATheme.textTertiary
        }
    }
}

// MARK: - Stage requirement

struct StageRequirement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let isComplete: Bool
}

// MARK: - Context the guide uses to compute requirements

struct LifecycleContext {
    let profile: ClientCRMProfile
    let activities: [ClientActivity]
    let communications: [ClientCommunication]
    let notes: [ClientNote]
    let tasks: [ClientTask]
    let foundationCall: FoundationCall?

    var hasFoundationCallScheduled: Bool {
        guard let c = foundationCall else { return false }
        return c.status == .scheduled || c.status == .completed
    }
    var hasFoundationCallCompleted: Bool {
        foundationCall?.status == .completed
    }

    var hasAnyCommunication: Bool { !communications.isEmpty || profile.lastContactedAt != nil }
    var hasMeetingOrCall: Bool { communications.contains { $0.kind == .call || $0.kind == .meeting } }
    var hasEmailOrSms: Bool { communications.contains { $0.kind == .email || $0.kind == .sms } }
    var hasNote: Bool { !notes.isEmpty }
    var hasPinnedNote: Bool { notes.contains { $0.pinned } }
    var hasTags: Bool { !profile.tags.isEmpty }
    var hasFollowUp: Bool { profile.nextFollowUpAt != nil && (profile.nextFollowUpAt ?? .distantPast) > .now }
    var hasOpenTask: Bool { tasks.contains { !$0.isCompleted } }
    var hasEnquiry: Bool { activities.contains { $0.kind == .enquirySent } }
    var hasFloorplanDownload: Bool { activities.contains { $0.kind == .floorplanDownload } }
    var hasDesignView: Bool { activities.contains { $0.kind == .designView } }

    func communicationsAfter(_ date: Date) -> Int {
        communications.filter { $0.occurredAt > date }.count
    }
}

// MARK: - Lifecycle guide

enum LifecycleStageGuide {
    /// Returns the checklist of requirements to advance from `stage` to its next stage.
    static func requirements(for stage: LeadStatus, ctx: LifecycleContext) -> [StageRequirement] {
        switch stage {
        case .new:
            return [
                StageRequirement(
                    id: "new.foundationCall",
                    title: "Book Foundation Call",
                    detail: "Primary goal — book the 30-min Cal.com video call to qualify the lead.",
                    icon: "video.fill",
                    isComplete: ctx.hasFoundationCallScheduled
                ),
                StageRequirement(
                    id: "new.firstContact",
                    title: "Log first contact",
                    detail: "Call, email, or SMS the client and log the touchpoint.",
                    icon: "phone.connection.fill",
                    isComplete: ctx.hasAnyCommunication
                ),
                StageRequirement(
                    id: "new.intro",
                    title: "Send AVIA intro",
                    detail: "Share a personalised welcome and overview of designs.",
                    icon: "envelope.fill",
                    isComplete: ctx.hasEmailOrSms || ctx.hasMeetingOrCall
                )
            ]
        case .contacted:
            return [
                StageRequirement(
                    id: "contacted.foundationCall",
                    title: "Complete Foundation Call",
                    detail: "Run the Cal.com video call and log the outcome to qualify them.",
                    icon: "video.fill",
                    isComplete: ctx.hasFoundationCallCompleted
                ),
                StageRequirement(
                    id: "contacted.discovery",
                    title: "Discovery conversation",
                    detail: "Have a call or meeting to understand their goals.",
                    icon: "bubble.left.and.bubble.right.fill",
                    isComplete: ctx.hasMeetingOrCall || ctx.hasFoundationCallCompleted
                ),
                StageRequirement(
                    id: "contacted.notes",
                    title: "Capture needs & budget",
                    detail: "Add a note covering budget, timeline, and must-haves.",
                    icon: "note.text",
                    isComplete: ctx.hasNote
                ),
                StageRequirement(
                    id: "contacted.tags",
                    title: "Tag qualifying info",
                    detail: "Tag with attributes like 'First Home', 'Investor', or 'Urgent'.",
                    icon: "tag.fill",
                    isComplete: ctx.hasTags
                ),
                StageRequirement(
                    id: "contacted.followup",
                    title: "Schedule next follow-up",
                    detail: "Set a future follow-up date so they don't go cold.",
                    icon: "calendar.badge.clock",
                    isComplete: ctx.hasFollowUp
                )
            ]
        case .qualified:
            return [
                StageRequirement(
                    id: "qualified.designs",
                    title: "Confirm preferred designs",
                    detail: "Client has viewed designs in-app or you've shortlisted with them.",
                    icon: "house.fill",
                    isComplete: ctx.hasDesignView || ctx.notes.contains { $0.body.localizedCaseInsensitiveContains("design") }
                ),
                StageRequirement(
                    id: "qualified.floorplan",
                    title: "Share floorplan / spec pack",
                    detail: "Floorplan downloaded or pricing pack sent.",
                    icon: "arrow.down.doc.fill",
                    isComplete: ctx.hasFloorplanDownload || ctx.hasEmailOrSms
                ),
                StageRequirement(
                    id: "qualified.proposalPrep",
                    title: "Prepare proposal task",
                    detail: "Add an open task to draft and send the proposal.",
                    icon: "checkmark.square.fill",
                    isComplete: ctx.hasOpenTask
                )
            ]
        case .proposal:
            let proposalSent = ctx.communications.contains {
                ($0.kind == .email || $0.kind == .meeting) &&
                ($0.summary.localizedCaseInsensitiveContains("proposal") ||
                 $0.summary.localizedCaseInsensitiveContains("pricing") ||
                 $0.summary.localizedCaseInsensitiveContains("quote"))
            }
            return [
                StageRequirement(
                    id: "proposal.sent",
                    title: "Proposal delivered",
                    detail: "Log the email/meeting where pricing or proposal was sent.",
                    icon: "doc.text.fill",
                    isComplete: proposalSent || ctx.hasEnquiry
                ),
                StageRequirement(
                    id: "proposal.feedback",
                    title: "Capture client feedback",
                    detail: "Pin a note summarising their reaction & objections.",
                    icon: "pin.fill",
                    isComplete: ctx.hasPinnedNote
                ),
                StageRequirement(
                    id: "proposal.followup",
                    title: "Schedule review meeting",
                    detail: "Book a time to walk through the proposal together.",
                    icon: "calendar.badge.plus",
                    isComplete: ctx.hasFollowUp
                )
            ]
        case .negotiation:
            return [
                StageRequirement(
                    id: "negotiation.touchpoint",
                    title: "Recent touchpoint",
                    detail: "A call or meeting in the last 7 days keeps momentum.",
                    icon: "flame.fill",
                    isComplete: ctx.communicationsAfter(.now.addingTimeInterval(-7 * 86400)) > 0
                ),
                StageRequirement(
                    id: "negotiation.terms",
                    title: "Agree on terms",
                    detail: "Pin a note capturing the agreed scope, price, and inclusions.",
                    icon: "checkmark.seal.fill",
                    isComplete: ctx.hasPinnedNote
                ),
                StageRequirement(
                    id: "negotiation.signing",
                    title: "Schedule contract signing",
                    detail: "Add a task to send and sign the contract.",
                    icon: "signature",
                    isComplete: ctx.hasOpenTask
                )
            ]
        case .won, .lost:
            return []
        }
    }
}
