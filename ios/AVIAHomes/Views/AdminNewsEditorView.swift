import SwiftUI

struct AdminNewsEditorView: View {
    @State private var viewModel = AdminCatalogViewModel()
    @State private var searchText = ""
    @State private var filterCategory: String = "All"
    @State private var editingPost: BlogPost?
    @State private var showingAddSheet = false
    @State private var postToDelete: BlogPost?

    private let categories = ["All", "Design Tips", "Company News", "Build Guide"]

    private var filteredPosts: [BlogPost] {
        var posts = viewModel.blogPosts
        if filterCategory != "All" {
            posts = posts.filter { $0.category == filterCategory }
        }
        if !searchText.isEmpty {
            posts = posts.filter {
                $0.title.localizedStandardContains(searchText) ||
                $0.subtitle.localizedStandardContains(searchText) ||
                $0.category.localizedStandardContains(searchText)
            }
        }
        return posts.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                categoryFilter
                statsBar

                if viewModel.isLoading {
                    ProgressView()
                        .tint(AVIATheme.timelessBrown)
                        .padding(.vertical, 60)
                } else if filteredPosts.isEmpty {
                    AdminEmptyState(
                        icon: "newspaper",
                        title: "No Articles",
                        subtitle: "Tap + to publish your first news article"
                    )
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredPosts, id: \.id) { post in
                            postCard(post)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("News Articles")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search articles...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddSheet = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            BlogPostEditSheet(post: nil) { post in
                Task { await viewModel.saveBlogPost(post) }
            }
        }
        .sheet(item: $editingPost) { post in
            BlogPostEditSheet(post: post) { updated in
                Task { await viewModel.saveBlogPost(updated) }
            }
        }
        .alert("Delete Article", isPresented: .init(
            get: { postToDelete != nil },
            set: { if !$0 { postToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { postToDelete = nil }
            Button("Delete", role: .destructive) {
                if let post = postToDelete {
                    Task { await viewModel.deleteBlogPost(id: post.id) }
                }
            }
        } message: {
            Text("Are you sure you want to delete \"\(postToDelete?.title ?? "")\"? This cannot be undone.")
        }
        .overlay(alignment: .bottom) { toastOverlay }
        .task { await viewModel.loadBlogPosts() }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(categories, id: \.self) { category in
                    categoryChip(category)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func categoryChip(_ value: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { filterCategory = value }
        } label: {
            Text(value)
                .font(.neueCaptionMedium)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .foregroundStyle(filterCategory == value ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                .background(filterCategory == value ? AVIATheme.timelessBrown : AVIATheme.cardBackground)
                .clipShape(Capsule())
                .overlay {
                    if filterCategory != value {
                        Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                    }
                }
        }
    }

    private var statsBar: some View {
        HStack(spacing: 12) {
            AdminMiniStat(value: "\(viewModel.blogPosts.count)", label: "Total", color: AVIATheme.timelessBrown)
            AdminMiniStat(
                value: "\(viewModel.blogPosts.filter { Calendar.current.isDate($0.date, equalTo: .now, toGranularity: .month) }.count)",
                label: "This Month",
                color: AVIATheme.success
            )
            AdminMiniStat(
                value: "\(Set(viewModel.blogPosts.map(\.category)).count)",
                label: "Categories",
                color: AVIATheme.heritageBlue
            )
        }
    }

    private func postCard(_ post: BlogPost) -> some View {
        Button { editingPost = post } label: {
            BentoCard(cornerRadius: 11) {
                HStack(spacing: 12) {
                    Color(.secondarySystemBackground)
                        .frame(width: 88, height: 88)
                        .overlay {
                            AsyncImage(url: URL(string: post.imageURL)) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Image(systemName: "photo")
                                        .font(.title3)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }
                            }
                            .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadius: 9))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(post.category.uppercased())
                            .font(.neueCorpMedium(9))
                            .kerning(0.6)
                            .foregroundStyle(AVIATheme.timelessBrown)

                        Text(post.title)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        HStack(spacing: 8) {
                            Text(post.readTime)
                            Text("·")
                            Text(post.date.formatted(.dateTime.month(.abbreviated).day().year()))
                        }
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .padding(12)
            }
        }
        .contextMenu {
            Button { editingPost = post } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) { postToDelete = post } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = viewModel.successMessage {
            Text(msg)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(AVIATheme.success, in: Capsule())
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { viewModel.successMessage = nil }
                    }
                }
        }
        if let msg = viewModel.errorMessage {
            Text(msg)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(AVIATheme.destructive, in: Capsule())
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { viewModel.errorMessage = nil }
                    }
                }
        }
    }
}

struct BlogPostEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let post: BlogPost?
    let onSave: (BlogPost) -> Void

    @State private var postId: String = ""
    @State private var title: String = ""
    @State private var subtitle: String = ""
    @State private var category: String = "Design Tips"
    @State private var imageURL: String = ""
    @State private var date: Date = .now
    @State private var readTime: String = "3 min read"
    @State private var content: String = ""

    private let categories = ["Design Tips", "Company News", "Build Guide"]

    private var isNew: Bool { post == nil }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        (isNew ? !postId.trimmingCharacters(in: .whitespaces).isEmpty : true)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    BentoCard(cornerRadius: 11) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Hero Image")
                            AdminImagePickerField(
                                label: "Article Image",
                                imageURL: $imageURL,
                                folder: "blog_posts",
                                itemId: isNew ? postId : (post?.id ?? postId)
                            )
                            .padding(.horizontal, 14)
                        }
                        .padding(.vertical, 14)
                    }

                    BentoCard(cornerRadius: 11) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Article Info")
                            if isNew {
                                sheetField("ID (lowercase, no spaces)") {
                                    TextField("e.g. choosing-the-right-facade", text: $postId)
                                        .font(.neueCaption)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                }
                            }
                            sheetField("Title") {
                                TextField("Article title", text: $title)
                                    .font(.neueCaption)
                            }
                            sheetField("Subtitle") {
                                TextField("Short summary", text: $subtitle, axis: .vertical)
                                    .font(.neueCaption)
                                    .lineLimit(2...4)
                            }
                            sheetField("Category") {
                                Picker("", selection: $category) {
                                    ForEach(categories, id: \.self) { cat in
                                        Text(cat).tag(cat)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(AVIATheme.textPrimary)
                            }
                            sheetField("Read Time") {
                                TextField("e.g. 3 min read", text: $readTime)
                                    .font(.neueCaption)
                            }
                            sheetField("Publish Date") {
                                DatePicker("", selection: $date, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(AVIATheme.timelessBrown)
                            }
                        }
                        .padding(.vertical, 14)
                    }

                    BentoCard(cornerRadius: 11) {
                        VStack(alignment: .leading, spacing: 14) {
                            sectionHeader("Article Content")
                            sheetField("Body") {
                                TextField("Write the full article here...", text: $content, axis: .vertical)
                                    .font(.neueCaption)
                                    .lineLimit(10...30)
                            }
                        }
                        .padding(.vertical, 14)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AVIATheme.background)
            .navigationTitle(isNew ? "New Article" : "Edit Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
        }
        .onAppear { populateFields() }
        .presentationDetents([.large])
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.neueCaptionMedium)
            .foregroundStyle(AVIATheme.textSecondary)
            .textCase(.uppercase)
            .kerning(0.5)
            .padding(.horizontal, 14)
    }

    private func sheetField(_ label: String, @ViewBuilder field: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
            field()
                .padding(10)
                .background(AVIATheme.surfaceElevated)
                .clipShape(.rect(cornerRadius: 6))
        }
        .padding(.horizontal, 14)
    }

    private func populateFields() {
        guard let post else { return }
        postId = post.id
        title = post.title
        subtitle = post.subtitle
        category = post.category
        imageURL = post.imageURL
        date = post.date
        readTime = post.readTime
        content = post.content
    }

    private func save() {
        let result = BlogPost(
            id: isNew ? postId.trimmingCharacters(in: .whitespaces) : (post?.id ?? postId),
            title: title.trimmingCharacters(in: .whitespaces),
            subtitle: subtitle.trimmingCharacters(in: .whitespaces),
            category: category,
            imageURL: imageURL,
            date: date,
            readTime: readTime.trimmingCharacters(in: .whitespaces),
            content: content
        )
        onSave(result)
        dismiss()
    }
}
