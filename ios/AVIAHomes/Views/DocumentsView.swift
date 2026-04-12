import SwiftUI

struct DocumentsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var searchText = ""
    @State private var selectedFilter: DocumentCategory?

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
            ScrollView {
                VStack(spacing: 16) {
                    filterChips

                    if filteredDocuments.isEmpty {
                        ContentUnavailableView(
                            "No Documents Found",
                            systemImage: "doc.text.magnifyingglass",
                            description: Text("Try adjusting your search or filter.")
                        )
                        .foregroundStyle(AVIATheme.textSecondary)
                        .padding(.top, 40)
                    } else {
                        ForEach(groupedDocuments, id: \.0) { category, docs in
                            VStack(alignment: .leading, spacing: 10) {
                                Label(category.rawValue, systemImage: category.icon)
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                    .padding(.leading, 4)

                                BentoCard(cornerRadius: 14) {
                                    VStack(spacing: 0) {
                                        ForEach(Array(docs.enumerated()), id: \.element.id) { index, doc in
                                            DocumentRow(document: doc)
                                            if index < docs.count - 1 {
                                                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 56)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search documents")
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: selectedFilter == nil) {
                    selectedFilter = nil
                }
                ForEach(DocumentCategory.allCases, id: \.self) { category in
                    FilterChip(title: category.rawValue, isSelected: selectedFilter == category) {
                        selectedFilter = selectedFilter == category ? nil : category
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
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
                        Capsule().fill(AVIATheme.teal)
                    } else {
                        Capsule().fill(AVIATheme.cardBackground)
                    }
                }
                .foregroundStyle(isSelected ? .white : AVIATheme.textSecondary)
                .overlay {
                    if !isSelected {
                        Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2), value: isSelected)
    }
}

struct DocumentRow: View {
    let document: ClientDocument

    var body: some View {
        HStack(spacing: 14) {
            BentoIconCircle(icon: document.category.icon, color: AVIATheme.teal)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(document.name)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(1)
                    if document.isNew {
                        StatusBadge(title: "NEW", color: AVIATheme.teal)
                    }
                }
                HStack(spacing: 8) {
                    Text(document.dateAdded.formatted(date: .abbreviated, time: .omitted))
                    Text("·")
                    Text(document.fileSize)
                }
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
            }

            Spacer()

            Image(systemName: "arrow.down.circle")
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
