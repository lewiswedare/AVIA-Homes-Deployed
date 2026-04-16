import SwiftUI

struct NewsArticleDetailView: View {
    let post: BlogPost

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerImage
                articleContent
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(AVIATheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var headerImage: some View {
        Color(AVIATheme.surfaceElevated)
            .frame(height: 320)
            .overlay {
                AsyncImage(url: URL(string: post.imageURL)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    }
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: AVIATheme.background.opacity(0.6), location: 0.6),
                        .init(color: AVIATheme.background, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)
            }
            .clipped()
    }

    private var articleContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(post.category.uppercased())
                .font(.neueCorpMedium(11))
                .kerning(1.0)
                .foregroundStyle(AVIATheme.timelessBrown)

            Text(post.title)
                .font(.neueCorpMedium(26))
                .foregroundStyle(AVIATheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(post.subtitle)
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Label(post.readTime, systemImage: "clock")
                Label(post.date.formatted(.dateTime.day().month(.wide).year()), systemImage: "calendar")
            }
            .font(.neueCaption)
            .foregroundStyle(AVIATheme.textTertiary)

            Divider()
                .padding(.vertical, 4)

            if !post.content.isEmpty {
                ForEach(post.content.components(separatedBy: "\n\n"), id: \.self) { paragraph in
                    Text(paragraph)
                        .font(.neueBody)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("Full article content coming soon.")
                    .font(.neueBody)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .italic()
            }

            Spacer(minLength: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, -20)
    }
}
