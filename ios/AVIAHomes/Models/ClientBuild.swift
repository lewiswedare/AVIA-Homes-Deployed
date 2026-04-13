import Foundation

nonisolated struct ClientBuild: Identifiable, Sendable {
    let id: String
    let client: ClientUser
    let additionalClients: [ClientUser]
    let homeDesign: String
    let lotNumber: String
    let estate: String
    let contractDate: Date
    let buildStages: [BuildStage]
    let assignedStaffId: String
    let salesPartnerId: String?
    let isCustom: Bool
    let selectedFacadeId: String?
    let customBedrooms: Int?
    let customBathrooms: Int?
    let customGarages: Int?
    let customSquareMeters: Double?
    let customStoreys: Int?
    let preConstructionStaffId: String?
    let buildingSupportStaffId: String?
    let handoverTriggeredAt: String?
    let buildStatus: String

    var allClients: [ClientUser] {
        var result = [client]
        result.append(contentsOf: additionalClients)
        return result.filter { !$0.id.isEmpty }
    }

    var allClientIds: [String] {
        var ids = [client.id]
        ids.append(contentsOf: additionalClients.map(\.id))
        return ids.filter { !$0.isEmpty }
    }

    var clientDisplayName: String {
        let primary = client.fullName.trimmingCharacters(in: .whitespaces)
        if primary.isEmpty { return "Unassigned" }
        if additionalClients.isEmpty { return primary }
        let others = additionalClients.map { $0.firstName }.joined(separator: ", ")
        return "\(primary) & \(others)"
    }

    func hasClient(id userId: String) -> Bool {
        client.id == userId || additionalClients.contains { $0.id == userId }
    }

    init(id: String, client: ClientUser, homeDesign: String, lotNumber: String, estate: String, contractDate: Date, buildStages: [BuildStage], assignedStaffId: String, salesPartnerId: String?, isCustom: Bool = false, selectedFacadeId: String? = nil, customBedrooms: Int? = nil, customBathrooms: Int? = nil, customGarages: Int? = nil, customSquareMeters: Double? = nil, customStoreys: Int? = nil, additionalClients: [ClientUser] = [], preConstructionStaffId: String? = nil, buildingSupportStaffId: String? = nil, handoverTriggeredAt: String? = nil, buildStatus: String = "active") {
        self.id = id
        self.client = client
        self.additionalClients = additionalClients
        self.homeDesign = homeDesign
        self.lotNumber = lotNumber
        self.estate = estate
        self.contractDate = contractDate
        self.buildStages = buildStages
        self.assignedStaffId = assignedStaffId
        self.salesPartnerId = salesPartnerId
        self.isCustom = isCustom
        self.selectedFacadeId = selectedFacadeId
        self.customBedrooms = customBedrooms
        self.customBathrooms = customBathrooms
        self.customGarages = customGarages
        self.customSquareMeters = customSquareMeters
        self.customStoreys = customStoreys
        self.preConstructionStaffId = preConstructionStaffId
        self.buildingSupportStaffId = buildingSupportStaffId
        self.handoverTriggeredAt = handoverTriggeredAt
        self.buildStatus = buildStatus
    }

    var currentStage: BuildStage? {
        buildStages.first { $0.status == .inProgress }
    }

    var overallProgress: Double {
        guard !buildStages.isEmpty else { return 0 }
        let total = Double(buildStages.count)
        let completed = Double(buildStages.filter { $0.status == .completed }.count)
        let inProgress = buildStages.first { $0.status == .inProgress }
        let progressContribution = (inProgress?.progress ?? 0) / total
        return (completed / total) + progressContribution
    }

    var statusLabel: String {
        currentStage?.name ?? "Pre-Construction"
    }

    static let samples: [ClientBuild] = []
}
