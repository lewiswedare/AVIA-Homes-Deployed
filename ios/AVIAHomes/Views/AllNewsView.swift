import SwiftUI

struct AllNewsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedCategory: String = "All"

    private let categories = ["All", "Design Tips", "Company News", "Build Guide"]

    private var filteredPosts: [BlogPost] {
        if selectedCategory == "All" {
            return viewModel.allBlogPosts
        }
        return viewModel.allBlogPosts.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerImage

                VStack(spacing: 24) {
                    titleSection
                    categoryFilter
                    newsContent
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea(edges: [.top, .horizontal])
        .background(AVIATheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var headerImage: some View {
        Color(AVIATheme.surfaceElevated)
            .frame(height: 280)
            .overlay {
                Image("hero_facade")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: AVIATheme.background.opacity(0.15), location: 0.25),
                        .init(color: AVIATheme.background.opacity(0.4), location: 0.45),
                        .init(color: AVIATheme.background.opacity(0.7), location: 0.65),
                        .init(color: AVIATheme.background.opacity(0.9), location: 0.8),
                        .init(color: AVIATheme.background, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)
            }
            .clipped()
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("All News")
                .font(.neueCorpMedium(32))
                .foregroundStyle(AVIATheme.textPrimary)

            Text("Stay up to date with AVIA Homes")
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            selectedCategory = category
                        }
                    } label: {
                        Text(category)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(selectedCategory == category ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedCategory == category ? AVIATheme.aviaBlack : AVIATheme.cardBackground)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    private var newsContent: some View {
        LazyVStack(spacing: 16) {
            if let featured = filteredPosts.first {
                NavigationLink(value: featured) {
                    featuredCard(post: featured)
                }
                .buttonStyle(.pressable(.subtle))
            }

            ForEach(filteredPosts.dropFirst()) { post in
                NavigationLink(value: post) {
                    compactNewsRow(post: post)
                }
                .buttonStyle(.pressable(.subtle))
            }

            if filteredPosts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "newspaper")
                        .font(.neueCorpMedium(32))
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text("No articles in this category")
                        .font(.neueSubheadline)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    private func featuredCard(post: BlogPost) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(AVIATheme.surfaceElevated)
                .frame(height: 200)
                .overlay {
                    AsyncImage(url: URL(string: post.imageURL)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))
                .overlay(alignment: .topLeading) {
                    HStack(spacing: 6) {
                        AVIAChip("FEATURED", onLight: false)
                        AVIAChip(post.category.uppercased(), onLight: false)
                    }
                    .padding(12)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(post.title)
                    .font(.neueCorpMedium(20))
                    .foregroundStyle(AVIATheme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(post.subtitle)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 12) {
                    Label(post.readTime, systemImage: "clock")
                    Label(post.date.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 13))
    }

    private func compactNewsRow(post: BlogPost) -> some View {
        BentoCard(cornerRadius: 13) {
            HStack(spacing: 12) {
                Color(AVIATheme.surfaceElevated)
                    .frame(width: 88, height: 88)
                    .overlay {
                        AsyncImage(url: URL(string: post.imageURL)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 10))

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
                        Text(post.date.formatted(.dateTime.month(.abbreviated).day()))
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
}
