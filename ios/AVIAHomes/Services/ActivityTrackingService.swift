import Foundation

@MainActor
enum ActivityTrackingService {
    static func track(
        clientId: String,
        kind: ClientActivityKind,
        referenceId: String,
        referenceName: String
    ) {
        guard !clientId.isEmpty else { return }
        let activity = ClientActivity(
            id: UUID().uuidString,
            clientId: clientId,
            kind: kind,
            referenceId: referenceId,
            referenceName: referenceName,
            createdAt: .now
        )
        Task.detached {
            await SupabaseService.shared.logClientActivity(activity)
        }
    }
}
