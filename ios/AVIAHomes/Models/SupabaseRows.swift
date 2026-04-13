import Foundation

nonisolated struct BuildRow: Codable, Sendable {
    let id: String
    let client_id: String
    let additional_client_ids: [String]?
    let home_design: String
    let lot_number: String
    let estate: String
    let contract_date: String
    let assigned_staff_id: String
    let sales_partner_id: String?
    let created_at: String?
    let updated_at: String?
    let is_custom: Bool?
    let selected_facade_id: String?
    let custom_bedrooms: Int?
    let custom_bathrooms: Int?
    let custom_garages: Int?
    let custom_square_meters: Double?
    let custom_storeys: Int?

    nonisolated enum CodingKeys: String, CodingKey {
        case id, client_id, additional_client_ids, home_design, lot_number, estate
        case contract_date, assigned_staff_id, sales_partner_id
        case created_at, updated_at
        case is_custom, selected_facade_id
        case custom_bedrooms, custom_bathrooms, custom_garages
        case custom_square_meters, custom_storeys
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(client_id, forKey: .client_id)
        try container.encodeIfPresent(additional_client_ids, forKey: .additional_client_ids)
        try container.encode(home_design, forKey: .home_design)
        try container.encode(lot_number, forKey: .lot_number)
        try container.encode(estate, forKey: .estate)
        try container.encode(contract_date, forKey: .contract_date)
        try container.encode(assigned_staff_id, forKey: .assigned_staff_id)
        try container.encodeIfPresent(sales_partner_id, forKey: .sales_partner_id)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)
        try container.encodeIfPresent(is_custom, forKey: .is_custom)
        try container.encodeIfPresent(selected_facade_id, forKey: .selected_facade_id)
        try container.encodeIfPresent(custom_bedrooms, forKey: .custom_bedrooms)
        try container.encodeIfPresent(custom_bathrooms, forKey: .custom_bathrooms)
        try container.encodeIfPresent(custom_garages, forKey: .custom_garages)
        try container.encodeIfPresent(custom_square_meters, forKey: .custom_square_meters)
        try container.encodeIfPresent(custom_storeys, forKey: .custom_storeys)
    }

    init(from build: ClientBuild) {
        let iso = ISO8601DateFormatter()
        id = build.id
        client_id = build.client.id
        additional_client_ids = build.additionalClients.map(\.id).filter { !$0.isEmpty }
        home_design = build.homeDesign
        lot_number = build.lotNumber
        estate = build.estate
        contract_date = iso.string(from: build.contractDate)
        assigned_staff_id = build.assignedStaffId
        sales_partner_id = build.salesPartnerId
        created_at = nil
        updated_at = iso.string(from: .now)
        is_custom = build.isCustom
        selected_facade_id = build.selectedFacadeId
        custom_bedrooms = build.customBedrooms
        custom_bathrooms = build.customBathrooms
        custom_garages = build.customGarages
        custom_square_meters = build.customSquareMeters
        custom_storeys = build.customStoreys
    }

    func toClientBuild(client: ClientUser, stages: [BuildStage], additionalClients: [ClientUser] = []) -> ClientBuild {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        let date = formatter.date(from: contract_date) ?? fallback.date(from: contract_date) ?? .now
        return ClientBuild(
            id: id,
            client: client,
            homeDesign: home_design,
            lotNumber: lot_number,
            estate: estate,
            contractDate: date,
            buildStages: stages,
            assignedStaffId: assigned_staff_id,
            salesPartnerId: sales_partner_id,
            isCustom: is_custom ?? false,
            selectedFacadeId: selected_facade_id,
            customBedrooms: custom_bedrooms,
            customBathrooms: custom_bathrooms,
            customGarages: custom_garages,
            customSquareMeters: custom_square_meters,
            customStoreys: custom_storeys,
            additionalClients: additionalClients
        )
    }
}

nonisolated struct BuildClientPatch: Encodable, Sendable {
    let client_id: String
    let additional_client_ids: [String]
}

nonisolated struct BuildStageRow: Codable, Sendable {
    let id: String
    let build_id: String
    let name: String
    let description: String
    let status: String
    let progress: Double
    let start_date: String?
    let completion_date: String?
    let notes: String?
    let photo_count: Int
    let sort_order: Int

    init(from stage: BuildStage, buildId: String, sortOrder: Int) {
        let iso = ISO8601DateFormatter()
        id = stage.id
        build_id = buildId
        name = stage.name
        description = stage.description
        status = stage.status.rawValue
        progress = stage.progress
        start_date = stage.startDate.map { iso.string(from: $0) }
        completion_date = stage.completionDate.map { iso.string(from: $0) }
        notes = stage.notes
        photo_count = stage.photoCount
        sort_order = sortOrder
    }

    func toBuildStage() -> BuildStage {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        return BuildStage(
            id: id,
            name: name,
            description: description,
            status: BuildStage.StageStatus(rawValue: status) ?? .upcoming,
            progress: progress,
            startDate: start_date.flatMap { formatter.date(from: $0) ?? fallback.date(from: $0) },
            completionDate: completion_date.flatMap { formatter.date(from: $0) ?? fallback.date(from: $0) },
            notes: notes,
            photoCount: photo_count
        )
    }
}

nonisolated struct PackageAssignmentRow: Codable, Sendable {
    let id: String
    let package_id: String
    let assigned_partner_ids: [String]
    let shared_with_client_ids: [String]
    let client_responses: [ClientResponseRow]
    let is_exclusive: Bool
    let created_at: String?
    let updated_at: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case id, package_id, assigned_partner_ids, shared_with_client_ids
        case client_responses, is_exclusive, created_at, updated_at
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(package_id, forKey: .package_id)
        try container.encode(assigned_partner_ids, forKey: .assigned_partner_ids)
        try container.encode(shared_with_client_ids, forKey: .shared_with_client_ids)
        try container.encode(client_responses, forKey: .client_responses)
        try container.encode(is_exclusive, forKey: .is_exclusive)
        try container.encodeIfPresent(updated_at, forKey: .updated_at)
    }

    init(from assignment: PackageAssignment) {
        let iso = ISO8601DateFormatter()
        id = assignment.id
        package_id = assignment.packageId
        assigned_partner_ids = assignment.assignedPartnerIds
        shared_with_client_ids = assignment.sharedWithClientIds
        client_responses = assignment.clientResponses.map { ClientResponseRow(from: $0) }
        is_exclusive = assignment.isExclusive
        created_at = nil
        updated_at = iso.string(from: .now)
    }

    func toPackageAssignment() -> PackageAssignment {
        PackageAssignment(
            id: id,
            packageId: package_id,
            assignedPartnerIds: assigned_partner_ids,
            sharedWithClientIds: shared_with_client_ids,
            clientResponses: client_responses.map { $0.toClientPackageResponse() },
            isExclusive: is_exclusive
        )
    }
}

nonisolated struct ClientResponseRow: Codable, Sendable {
    let client_id: String
    let status: String
    let responded_date: String?
    let notes: String?

    init(from response: ClientPackageResponse) {
        let iso = ISO8601DateFormatter()
        client_id = response.clientId
        status = response.status.rawValue
        responded_date = response.respondedDate.map { iso.string(from: $0) }
        notes = response.notes
    }

    func toClientPackageResponse() -> ClientPackageResponse {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        return ClientPackageResponse(
            clientId: client_id,
            status: PackageResponseStatus(rawValue: status) ?? .pending,
            respondedDate: responded_date.flatMap { formatter.date(from: $0) ?? fallback.date(from: $0) },
            notes: notes
        )
    }
}

nonisolated struct ServiceRequestRow: Codable, Sendable {
    let id: String
    let client_id: String
    let build_id: String?
    let title: String
    let description: String
    let category: String
    let status: String
    let date_created: String?
    let last_updated: String?
    let responses: [RequestResponseRow]
    let created_at: String?
    let updated_at: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case id, client_id, build_id, title, description, category, status
        case date_created, last_updated, responses, created_at, updated_at
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        client_id = try container.decode(String.self, forKey: .client_id)
        build_id = try container.decodeIfPresent(String.self, forKey: .build_id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        category = try container.decode(String.self, forKey: .category)
        status = try container.decode(String.self, forKey: .status)
        date_created = try container.decodeIfPresent(String.self, forKey: .date_created)
        last_updated = try container.decodeIfPresent(String.self, forKey: .last_updated)
        responses = (try? container.decodeIfPresent([RequestResponseRow].self, forKey: .responses)) ?? []
        created_at = try container.decodeIfPresent(String.self, forKey: .created_at)
        updated_at = try container.decodeIfPresent(String.self, forKey: .updated_at)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(client_id, forKey: .client_id)
        try container.encodeIfPresent(build_id, forKey: .build_id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(category, forKey: .category)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(date_created, forKey: .date_created)
        try container.encodeIfPresent(last_updated, forKey: .last_updated)
        try container.encode(responses, forKey: .responses)
    }

    init(from request: ServiceRequest, clientId: String, buildId: String? = nil) {
        let iso = ISO8601DateFormatter()
        id = request.id
        client_id = clientId
        build_id = buildId
        title = request.title
        description = request.description
        category = request.category.rawValue
        status = request.status.rawValue
        date_created = iso.string(from: request.dateCreated)
        last_updated = iso.string(from: request.lastUpdated)
        responses = request.responses.map { RequestResponseRow(from: $0) }
        created_at = nil
        updated_at = nil
    }

    func toServiceRequest() -> ServiceRequest {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        let createdDate = (date_created.flatMap { formatter.date(from: $0) ?? fallback.date(from: $0) })
            ?? (created_at.flatMap { formatter.date(from: $0) ?? fallback.date(from: $0) })
            ?? .now
        let updatedDate = (last_updated.flatMap { formatter.date(from: $0) ?? fallback.date(from: $0) })
            ?? (updated_at.flatMap { formatter.date(from: $0) ?? fallback.date(from: $0) })
            ?? .now
        return ServiceRequest(
            id: id,
            title: title,
            description: description,
            category: RequestCategory(rawValue: category) ?? .general,
            status: RequestStatus(rawValue: status) ?? .open,
            dateCreated: createdDate,
            lastUpdated: updatedDate,
            responses: responses.map { $0.toRequestResponse() },
            attachedPhotos: []
        )
    }
}

nonisolated struct RequestResponseRow: Codable, Sendable {
    let id: String
    let author: String
    let message: String
    let date: String
    let is_from_client: Bool

    init(from response: RequestResponse) {
        let iso = ISO8601DateFormatter()
        id = response.id
        author = response.author
        message = response.message
        date = iso.string(from: response.date)
        is_from_client = response.isFromClient
    }

    func toRequestResponse() -> RequestResponse {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        return RequestResponse(
            id: id,
            author: author,
            message: message,
            date: formatter.date(from: date) ?? fallback.date(from: date) ?? .now,
            isFromClient: is_from_client
        )
    }
}
