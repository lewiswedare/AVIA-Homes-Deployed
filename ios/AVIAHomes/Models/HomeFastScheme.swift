import Foundation

nonisolated struct SchemeRoomImage: Sendable {
    let room: String
    let label: String
    let assetName: String
}

nonisolated struct HomeFastScheme: Identifiable, Sendable {
    let id: String
    let name: String
    let subtitle: String
    let previewColors: [String]
    let selections: [String: SchemeSelection]
    let roomImages: [SchemeRoomImage]
}

nonisolated struct SchemeSelection: Sendable {
    let optionId: String
    let optionName: String
    let hexColor: String
}
