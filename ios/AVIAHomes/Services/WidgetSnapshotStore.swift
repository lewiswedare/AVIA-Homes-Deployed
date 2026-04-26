import Foundation
import WidgetKit

nonisolated enum WidgetSnapshotKind: String, Codable, Sendable {
    case noBuild
    case awaitingSpecs
    case awaitingColours
    case buildProgress
    case packageAssigned
}

nonisolated struct WidgetNewsItem: Codable, Sendable, Hashable {
    let id: String
    let title: String
    let excerpt: String
    let imageURL: String?
    let publishedAt: Date?
}

nonisolated struct WidgetStaffContact: Codable, Sendable, Hashable {
    let name: String
    let roleLabel: String
    let phone: String
    let email: String
}

nonisolated struct WidgetPackageSummary: Codable, Sendable, Hashable {
    let title: String
    let location: String
    let homeDesign: String
    let price: String
    let bedrooms: Int
    let bathrooms: Int
    let garages: Int
    let imageURL: String?
    let responseStatus: String
}

nonisolated struct WidgetSnapshot: Codable, Sendable {
    let kind: WidgetSnapshotKind
    let userFirstName: String
    let homeDesign: String
    let estate: String
    let lotNumber: String
    let currentStageName: String
    let currentStageDescription: String
    let overallProgress: Double
    let stageProgress: Double
    let totalStages: Int
    let completedStages: Int
    let isAwaitingRegistration: Bool
    let specsRemaining: Int
    let specsTotal: Int
    let coloursRemaining: Int
    let coloursTotal: Int
    let nextStepTitle: String
    let nextStepDetail: String
    let staff: WidgetStaffContact?
    let package: WidgetPackageSummary?
    let news: [WidgetNewsItem]
    let updatedAt: Date

    static let placeholder = WidgetSnapshot(
        kind: .noBuild,
        userFirstName: "",
        homeDesign: "",
        estate: "",
        lotNumber: "",
        currentStageName: "",
        currentStageDescription: "",
        overallProgress: 0,
        stageProgress: 0,
        totalStages: 0,
        completedStages: 0,
        isAwaitingRegistration: false,
        specsRemaining: 0,
        specsTotal: 0,
        coloursRemaining: 0,
        coloursTotal: 0,
        nextStepTitle: "",
        nextStepDetail: "",
        staff: nil,
        package: nil,
        news: [],
        updatedAt: .now
    )
}

nonisolated enum WidgetSnapshotStore {
    static let appGroupID = "group.com.wedare.aviahomes"
    static let snapshotKey = "avia_widget_snapshot_v2"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func read() -> WidgetSnapshot {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: snapshotKey) else {
            return .placeholder
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data) {
            return snapshot
        }
        return .placeholder
    }

    static func write(_ snapshot: WidgetSnapshot) {
        guard let defaults = sharedDefaults else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    static func clear() {
        guard let defaults = sharedDefaults else { return }
        defaults.removeObject(forKey: snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
