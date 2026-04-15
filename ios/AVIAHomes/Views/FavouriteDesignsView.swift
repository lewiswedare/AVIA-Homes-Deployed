import SwiftUI

struct FavouriteDesignsView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            if viewModel.favouriteDesigns.isEmpty {
                emptyState
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                    ForEach(viewModel.favouriteDesigns) { design in
                        NavigationLink(value: design) {
                            favouriteCard(design: design)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .background(AVIATheme.background)
        .navigationTitle("My Favourites")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: HomeDesign.self) { design in
            HomeDesignDetailView(design: design)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "heart.slash")
                .font(.system(size: 40))
                .foregroundStyle(AVIATheme.textTertiary)
            Text("No favourites yet")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textSecondary)
            Text("Tap the heart icon on any design to save it here.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .padding(.horizontal, 40)
    }

    private func favouriteCard(design: HomeDesign) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(AVIATheme.surfaceElevated)
                .aspectRatio(4/3, contentMode: .fit)
                .overlay {
                    AsyncImage(url: URL(string: design.imageURL)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            Image(systemName: "house.fill")
                                .font(.neueCorpMedium(28))
                                .foregroundStyle(AVIATheme.teal.opacity(0.3))
                        } else {
                            ProgressView()
                        }
                    }
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.toggleDesignFavourite(design.id)
                        }
                    } label: {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.red)
                            .frame(width: 30, height: 30)
                            .background(.black.opacity(0.35))
                            .clipShape(Circle())
                            .padding(8)
                    }
                }
                .clipShape(.rect(cornerRadii: .init(topLeading: 14, topTrailing: 14)))

            VStack(alignment: .leading, spacing: 6) {
                Text(design.name)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)

                HStack(spacing: 8) {
                    Label("\(design.bedrooms)", systemImage: "bed.double.fill")
                    Label("\(design.bathrooms)", systemImage: "shower.fill")
                    Label("\(design.garages)", systemImage: "car.fill")
                }
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textSecondary)

                Text(String(format: "%.0fm\u{00B2}", design.squareMeters))
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.teal)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 14))
    }
}
