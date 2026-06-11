import SwiftUI
import UniformTypeIdentifiers

/// Admin-managed shared "stock" document library. Admins upload reusable files
/// (brochures, standard contracts, templates, marketing collateral) here once so
/// staff can attach them to any client email without re-uploading.
struct AdminDocumentLibraryView: View {
    @Environment(AppViewModel.self) private var viewModel

    @State private var documents: [LibraryDocument] = []
    @State private var isLoading: Bool = true
    @State private var showUpload: Bool = false
    @State private var docToEdit: LibraryDocument?
    @State private var docToDelete: LibraryDocument?

    private var grouped: [(DocumentCategory, [LibraryDocument])] {
        DocumentCategory.allCases.compactMap { category in
            let docs = documents.filter { $0.category == category }
            return docs.isEmpty ? nil : (category, docs)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                intro
                if isLoading && documents.isEmpty {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                } else if documents.isEmpty {
                    AdminEmptyState(
                        icon: "tray.full",
                        title: "No stock files yet",
                        subtitle: "Upload brochures, standard contracts and templates here so your team can send them in a tap."
                    )
                } else {
                    ForEach(grouped, id: \.0) { category, docs in
                        categorySection(category, docs)
                    }
                }
            }
            .padding(16)
            .adaptiveContentWidth()
        }
        .background(AVIATheme.background)
        .navigationTitle("Stock Library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    docToEdit = nil
                    showUpload = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showUpload) {
            LibraryDocumentEditorSheet(existing: docToEdit, uploaderId: viewModel.currentUser.id) {
                await load()
            }
        }
        .sheet(item: $docToEdit) { doc in
            LibraryDocumentEditorSheet(existing: doc, uploaderId: viewModel.currentUser.id) {
                await load()
            }
        }
        .alert("Delete file?", isPresented: Binding(get: { docToDelete != nil }, set: { if !$0 { docToDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let doc = docToDelete { Task { await delete(doc) } }
            }
            Button("Cancel", role: .cancel) { docToDelete = nil }
        } message: {
            Text("\"\(docToDelete?.name ?? "")\" will be removed from the stock library. Emails already sent are unaffected.")
        }
    }

    private var intro: some View {
        BentoCard(cornerRadius: 12) {
            HStack(spacing: 12) {
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(width: 40, height: 40)
                    .background(AVIATheme.timelessBrown.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shared stock library")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Files here are available to every staff member when composing client emails.")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(14)
        }
    }

    private func categorySection(_ category: DocumentCategory, _ docs: [LibraryDocument]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(category.rawValue.uppercased())
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)
            ForEach(docs) { doc in
                Button {
                    docToEdit = doc
                } label: {
                    docRow(doc)
                }
                .buttonStyle(.pressable(.subtle))
            }
        }
    }

    private func docRow(_ doc: LibraryDocument) -> some View {
        BentoCard(cornerRadius: 11) {
            HStack(spacing: 12) {
                Image(systemName: doc.category.icon)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 36, height: 36)
                    .background(AVIATheme.timelessBrown)
                    .clipShape(.rect(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.name)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(1)
                    if let desc = doc.description, !desc.isEmpty {
                        Text(desc)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(1)
                    } else if !doc.fileSize.isEmpty {
                        Text(doc.fileSize)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }
                Spacer()
                Button {
                    docToDelete = doc
                } label: {
                    Image(systemName: "trash")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.destructive.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
        }
    }

    private func load() async {
        isLoading = true
        documents = await SupabaseService.shared.fetchLibraryDocuments()
        isLoading = false
    }

    private func delete(_ doc: LibraryDocument) async {
        _ = await SupabaseService.shared.deleteLibraryDocument(id: doc.id)
        docToDelete = nil
        await load()
    }
}

// MARK: - Editor / uploader

struct LibraryDocumentEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existing: LibraryDocument?
    let uploaderId: String
    let onSaved: () async -> Void

    @State private var name: String = ""
    @State private var category: DocumentCategory = .templates
    @State private var description: String = ""
    @State private var fileURL: String = ""
    @State private var fileSize: String = ""
    @State private var fileType: String = "application/pdf"

    @State private var showPicker: Bool = false
    @State private var isUploading: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    private var hasFile: Bool { !fileURL.isEmpty }
    private var canSave: Bool {
        hasFile && !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving && !isUploading
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    fileCard
                    fieldCard(title: "File name") {
                        TextField("e.g. AVIA Homes Brochure 2026", text: $name)
                            .font(.neueSubheadline)
                    }
                    categoryCard
                    fieldCard(title: "Description (optional)") {
                        TextField("Short note for your team", text: $description, axis: .vertical)
                            .font(.neueSubheadline)
                            .lineLimit(2...4)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.destructive)
                    }
                    saveButton
                }
                .padding(16)
            }
            .background(AVIATheme.background)
            .navigationTitle(existing == nil ? "Add stock file" : "Edit file")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: applyExisting)
            .fileImporter(
                isPresented: $showPicker,
                allowedContentTypes: [.pdf, .image, .plainText, UTType("com.microsoft.word.doc") ?? .data, .data]
            ) { result in
                if case .success(let url) = result {
                    Task { await upload(url) }
                } else if case .failure(let error) = result {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private var fileCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("FILE")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)
            Button {
                showPicker = true
            } label: {
                HStack(spacing: 12) {
                    if isUploading {
                        ProgressView().controlSize(.small).tint(AVIATheme.aviaWhite)
                            .frame(width: 36, height: 36)
                            .background(AVIATheme.timelessBrown)
                            .clipShape(.rect(cornerRadius: 9))
                    } else {
                        Image(systemName: hasFile ? category.icon : "doc.badge.plus")
                            .font(.neueSubheadline)
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .frame(width: 36, height: 36)
                            .background(hasFile ? AVIATheme.timelessBrown : AVIATheme.textTertiary)
                            .clipShape(.rect(cornerRadius: 9))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isUploading ? "Uploading…" : (hasFile ? "File ready" : "Choose a file"))
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text(hasFile ? (fileSize.isEmpty ? "Tap to replace" : "\(fileSize) · tap to replace") : "PDF, image or document")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.doc")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(AVIATheme.cardBackground)
                .clipShape(.rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10).stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(isUploading)
        }
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CATEGORY")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DocumentCategory.allCases, id: \.self) { cat in
                        Button {
                            category = cat
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: cat.icon).font(.neueCaption2)
                                Text(cat.rawValue).font(.neueCaption2Medium)
                            }
                            .foregroundStyle(category == cat ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(category == cat ? AVIATheme.timelessBrown : AVIATheme.cardBackground)
                            .clipShape(.capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
        }
    }

    private func fieldCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AVIATheme.cardBackground)
                .clipShape(.rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10).stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                }
        }
    }

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack(spacing: 8) {
                if isSaving { ProgressView().tint(AVIATheme.aviaWhite) }
                Text(existing == nil ? "Add to library" : "Save changes")
                    .font(.neueSubheadlineMedium)
            }
            .foregroundStyle(AVIATheme.aviaWhite)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(canSave ? AnyShapeStyle(AVIATheme.primaryGradient) : AnyShapeStyle(AVIATheme.textTertiary.opacity(0.5)))
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private func applyExisting() {
        guard let existing else { return }
        name = existing.name
        category = existing.category
        description = existing.description ?? ""
        fileURL = existing.fileURL
        fileSize = existing.fileSize
        fileType = existing.fileType
    }

    private func upload(_ url: URL) async {
        errorMessage = nil
        isUploading = true
        defer { isUploading = false }

        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "Couldn't read that file."
            return
        }
        let originalName = url.lastPathComponent
        let contentType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"

        guard let publicURL = await PDFUploadService.shared.uploadFile(
            data,
            fileName: originalName,
            folder: "library",
            contentType: contentType
        ) else {
            errorMessage = "Upload failed. Please try again."
            return
        }
        fileURL = publicURL
        fileType = contentType
        fileSize = Self.formatBytes(data.count)
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            name = (originalName as NSString).deletingPathExtension
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        let row = LibraryDocumentRow(
            id: existing?.id ?? UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            category: category,
            description: description.trimmingCharacters(in: .whitespaces).isEmpty ? nil : description.trimmingCharacters(in: .whitespaces),
            fileURL: fileURL,
            fileSize: fileSize,
            fileType: fileType,
            uploadedBy: uploaderId.isEmpty ? nil : uploaderId,
            sortOrder: 0
        )
        let ok = await SupabaseService.shared.upsertLibraryDocument(row)
        if ok {
            await onSaved()
            dismiss()
        } else {
            errorMessage = "Couldn't save. Please try again."
        }
    }

    static func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}
