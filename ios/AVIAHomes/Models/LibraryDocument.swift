import Foundation

/// A reusable "stock" document in the shared library. Admins upload these once and
/// staff can attach them to any client email — no client association.
nonisolated struct LibraryDocument: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let category: DocumentCategory
    let description: String?
    let fileURL: String
    let fileSize: String
    let fileType: String
    let createdAt: Date

    /// Represent this stock file as a `ClientDocument` so it can flow through the
    /// existing compose/attachment pipeline unchanged.
    func asAttachment() -> ClientDocument {
        ClientDocument(
            id: id,
            name: name,
            category: category,
            dateAdded: createdAt,
            fileSize: fileSize,
            isNew: false,
            fileURL: fileURL
        )
    }
}

nonisolated struct LibraryDocumentRow: Codable, Sendable {
    let id: String
    let name: String
    let category: String
    let description: String?
    let file_url: String
    let file_size: String
    let file_type: String
    let uploaded_by: String?
    let sort_order: Int?
    let created_at: String?

    nonisolated enum CodingKeys: String, CodingKey {
        case id, name, category, description
        case file_url, file_size, file_type, uploaded_by, sort_order, created_at
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(file_url, forKey: .file_url)
        try container.encode(file_size, forKey: .file_size)
        try container.encode(file_type, forKey: .file_type)
        try container.encodeIfPresent(uploaded_by, forKey: .uploaded_by)
        try container.encodeIfPresent(sort_order, forKey: .sort_order)
    }

    init(
        id: String,
        name: String,
        category: DocumentCategory,
        description: String?,
        fileURL: String,
        fileSize: String,
        fileType: String,
        uploadedBy: String?,
        sortOrder: Int
    ) {
        self.id = id
        self.name = name
        self.category = category.rawValue
        self.description = description
        self.file_url = fileURL
        self.file_size = fileSize
        self.file_type = fileType
        self.uploaded_by = uploadedBy
        self.sort_order = sortOrder
        self.created_at = nil
    }

    func toModel() -> LibraryDocument {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        let date = created_at.flatMap { formatter.date(from: $0) ?? fallback.date(from: $0) } ?? .now
        return LibraryDocument(
            id: id,
            name: name,
            category: DocumentCategory(rawValue: category) ?? .templates,
            description: description,
            fileURL: file_url,
            fileSize: file_size,
            fileType: file_type,
            createdAt: date
        )
    }
}
