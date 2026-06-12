import SwiftUI

enum DocumentsSection: String, CaseIterable, Hashable {
    case documents = "Documents"
    case contracts = "Contracts"
    case invoices = "Invoices"
}

struct DocumentsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var searchText = ""
    @State private var selectedFilter: DocumentCategory?
    @State private var section: DocumentsSection = .documents

    private var filteredDocuments: [ClientDocument] {
        var docs = viewModel.documents
        if let filter = selectedFilter {
            docs = docs.filter { $0.category == filter }
        }
        if !searchText.isEmpty {
            docs = docs.filter { $0.name.localizedStandardContains(searchText) }
        }
        return docs.sorted { $0.dateAdded > $1.dateAdded }
    }

    private var groupedDocuments: [(DocumentCategory, [ClientDocument])] {
        let grouped = Dictionary(grouping: filteredDocuments) { $0.category }
        return DocumentCategory.allCases.compactMap { category in
            guard let docs = grouped[category], !docs.isEmpty else { return nil }
            return (category, docs)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Section", selection: $section) {
                    ForEach(DocumentsSection.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

                switch section {
                case .documents:
                    documentsContent
                case .contracts:
                    ClientContractListContent()
                case .invoices:
                    ClientInvoiceListContent()
                }
            }
            .background(AVIATheme.background)
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var navTitle: String {
        switch section {
        case .documents: "Documents"
        case .contracts: "Contracts"
        case .invoices: "Invoices"
        }
    }

    private var documentsContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if filteredDocuments.isEmpty {
                    ContentUnavailableView(
                        "No Documents Found",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Try adjusting your search.")
                    )
                    .foregroundStyle(AVIATheme.textSecondary)
                    .padding(.top, 40)
                } else {
                    BentoCard(cornerRadius: 11) {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredDocuments.enumerated()), id: \.element.id) { index, doc in
                                DocumentRow(document: doc)
                                if index < filteredDocuments.count - 1 {
                                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 56)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 40)
            .adaptiveContentWidth()
        }
        .searchable(text: $searchText, prompt: "Search documents")
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.neueCaptionMedium)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background {
                    if isSelected {
                        Capsule().fill(AVIATheme.timelessBrown)
                    } else {
                        Capsule().fill(AVIATheme.cardBackground)
                    }
                }
                .foregroundStyle(isSelected ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                .overlay {
                    if !isSelected {
                        Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.pressable(.subtle))
        .animation(.spring(response: 0.2), value: isSelected)
    }
}

struct DocumentRow: View {
    let document: ClientDocument

    var body: some View {
        Group {
            if document.fileURL != nil {
                StorageFileLink(urlString: document.fileURL) {
                    rowContent
                }
            } else {
                rowContent
                    .opacity(0.7)
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 14) {
            BentoIconCircle(icon: document.category.icon, color: AVIATheme.timelessBrown)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(document.name)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(1)
                    if document.isNew {
                        StatusBadge(title: "NEW", color: AVIATheme.timelessBrown)
                    }
                    if let stage = document.buildStageName {
                        StatusBadge(title: stage, color: AVIATheme.warning)
                    }
                }
                HStack(spacing: 8) {
                    Text(document.dateAdded.formatted(date: .abbreviated, time: .omitted))
                    Text("·")
                    Text(document.fileSize)
                    if document.fileURL != nil {
                        Text("· Download")
                            .foregroundStyle(AVIATheme.timelessBrown)
                    } else {
                        Text("· No file attached")
                    }
                }
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
            }

            Spacer()

            Image(systemName: document.fileURL != nil ? "arrow.down.circle.fill" : "arrow.down.circle")
                .foregroundStyle(document.fileURL != nil ? AVIATheme.timelessBrown : AVIATheme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
