import SwiftUI

struct SiteMapViewer: View {
    let estateName: String
    var imageURL: String?
    var assetName: String?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    init(estateName: String, imageURL: String) {
        self.estateName = estateName
        self.imageURL = imageURL
        self.assetName = nil
    }

    init(estateName: String, assetName: String) {
        self.estateName = estateName
        self.imageURL = nil
        self.assetName = assetName
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                if let assetName, let uiImage = UIImage(named: assetName) {
                    zoomableImage(Image(uiImage: uiImage), size: geo.size)
                } else if let imageURL {
                    AsyncImage(url: URL(string: imageURL)) { phase in
                        if let image = phase.image {
                            zoomableImage(image, size: geo.size)
                        } else if phase.error != nil {
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.secondary)
                                Text("Failed to load site map")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: geo.size.width, height: geo.size.height)
                        } else {
                            ProgressView()
                                .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
                }
            }
            .background(Color.black)
            .navigationTitle("\(estateName) — Site Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AVIATheme.aviaBlack, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func zoomableImage(_ image: Image, size: CGSize) -> some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        let newScale = lastScale * value.magnification
                        scale = min(max(newScale, 1.0), 5.0)
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale <= 1.0 {
                            withAnimation(.spring(response: 0.3)) {
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                    }
                    .simultaneously(with:
                        DragGesture()
                            .onChanged { value in
                                guard scale > 1.0 else { return }
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.35)) {
                    if scale > 1.0 {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    } else {
                        scale = 2.5
                        lastScale = 2.5
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
    }
}
