import SwiftUI

struct DesignComparisonView: View {
    let designA: HomeDesign
    let designB: HomeDesign
    @Environment(\.dismiss) private var dismiss
    @State private var zoomedFloorplan: ZoomedFloorplan?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    floorplanRow
                    imageRow
                    statsSection
                    dimensionsSection
                    detailsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("Compare Designs")
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(item: $zoomedFloorplan) { item in
                FloorplanZoomView(design: item.design)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Floor Plan Row (Priority)

    private var floorplanRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("FLOOR PLANS")
                Spacer()
                Label("Tap to zoom", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            HStack(spacing: 10) {
                floorplanCard(design: designA)
                floorplanCard(design: designB)
            }
        }
    }

    private func floorplanCard(design: HomeDesign) -> some View {
        let url = design.floorplanImageURL
        return Button {
            zoomedFloorplan = ZoomedFloorplan(design: design)
        } label: {
            AVIATheme.aviaWhite
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    AsyncImage(url: URL(string: url)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fit).padding(8)
                        } else if phase.error != nil {
                            Image(systemName: "rectangle.split.2x2")
                                .font(.neueCorpMedium(28))
                                .foregroundStyle(AVIATheme.timelessBrown.opacity(0.3))
                        } else {
                            ProgressView()
                        }
                    }
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    Text(design.name)
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial, in: .capsule)
                        .padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .padding(6)
                        .background(AVIATheme.timelessBrown.opacity(0.85), in: .circle)
                        .padding(8)
                }
                .clipShape(.rect(cornerRadius: 11))
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Image Row

    private var imageRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("EXTERIOR")
            HStack(spacing: 10) {
                designImageCard(design: designA)
                designImageCard(design: designB)
            }
        }
    }

    private func designImageCard(design: HomeDesign) -> some View {
        AVIATheme.surfaceElevated
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                AsyncImage(url: URL(string: design.imageURL)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Image(systemName: "house.fill")
                            .font(.neueCorpMedium(28))
                            .foregroundStyle(AVIATheme.timelessBrown.opacity(0.3))
                    } else {
                        ProgressView()
                    }
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 2) {
                    Text(design.name)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .lineLimit(1)
                    Text(String(format: "%.0fm²", design.squareMeters))
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.aviaWhite.opacity(0.85))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .clipShape(.rect(cornerRadius: 11))
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("KEY STATS")

            BentoCard(cornerRadius: 13) {
                VStack(spacing: 0) {
                    comparisonRow(label: "Bedrooms", icon: "bed.double.fill", valueA: "\(designA.bedrooms)", valueB: "\(designB.bedrooms)")
                    rowDivider
                    comparisonRow(label: "Bathrooms", icon: "shower.fill", valueA: "\(designA.bathrooms)", valueB: "\(designB.bathrooms)")
                    rowDivider
                    comparisonRow(label: "Car Spaces", icon: "car.fill", valueA: "\(designA.garages)", valueB: "\(designB.garages)")
                    rowDivider
                    comparisonRow(label: "Living Areas", icon: "sofa.fill", valueA: "\(designA.livingAreas)", valueB: "\(designB.livingAreas)")
                    rowDivider
                    comparisonRow(label: "Storeys", icon: "building.2.fill", valueA: designA.storeys == 1 ? "Single" : "Double", valueB: designB.storeys == 1 ? "Single" : "Double")
                }
            }
        }
    }

    // MARK: - Dimensions Section

    private var dimensionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("DIMENSIONS")

            BentoCard(cornerRadius: 13) {
                VStack(spacing: 0) {
                    comparisonRow(label: "Total Area", icon: "square.dashed", valueA: String(format: "%.0f m²", designA.squareMeters), valueB: String(format: "%.0f m²", designB.squareMeters))
                    rowDivider
                    comparisonRow(label: "Width", icon: "arrow.left.and.right", valueA: String(format: "%.1fm", designA.houseWidth), valueB: String(format: "%.1fm", designB.houseWidth))
                    rowDivider
                    comparisonRow(label: "Length", icon: "arrow.up.and.down", valueA: String(format: "%.1fm", designA.houseLength), valueB: String(format: "%.1fm", designB.houseLength))
                    rowDivider
                    comparisonRow(label: "Min. Lot Width", icon: "ruler", valueA: String(format: "%.1fm", designA.lotWidth), valueB: String(format: "%.1fm", designB.lotWidth))
                }
            }
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("DETAILS")

            BentoCard(cornerRadius: 13) {
                VStack(spacing: 0) {
                    comparisonRow(label: "Price From", icon: "dollarsign.circle.fill", valueA: designA.priceFrom.isEmpty ? "–" : designA.priceFrom, valueB: designB.priceFrom.isEmpty ? "–" : designB.priceFrom)
                    rowDivider
                    comparisonRow(label: "Room Highlights", icon: "list.star", valueA: "\(designA.roomHighlights.count)", valueB: "\(designB.roomHighlights.count)")
                    rowDivider
                    comparisonRow(label: "Inclusions", icon: "checkmark.circle.fill", valueA: "\(designA.inclusions.count)", valueB: "\(designB.inclusions.count)")
                }
            }
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.neueCaption2Medium)
            .kerning(1.0)
            .foregroundStyle(AVIATheme.timelessBrown)
            .padding(.leading, 12)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(AVIATheme.timelessBrown)
                    .frame(width: 3)
            }
    }

    private func comparisonRow(label: String, icon: String, valueA: String, valueB: String) -> some View {
        HStack(spacing: 0) {
            Text(valueA)
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
                .frame(maxWidth: .infinity)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AVIATheme.textTertiary)
                .frame(width: 80)

            Text(valueB)
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(AVIATheme.surfaceBorder)
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
}

// MARK: - Floor Plan Zoom

private struct ZoomedFloorplan: Identifiable {
    let design: HomeDesign
    var id: String { design.id }
}

private struct FloorplanZoomView: View {
    let design: HomeDesign
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: design.floorplanImageURL)) { phase in
                if let image = phase.image {
                    image.resizable().aspectRatio(contentMode: .fit)
                } else if phase.error != nil {
                    Image(systemName: "rectangle.split.2x2")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.4))
                } else {
                    ProgressView().tint(.white)
                }
            }
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        scale = max(1.0, min(lastScale * value.magnification, 5.0))
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
            )
            .simultaneousGesture(
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
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3)) {
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

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(design.name)
                            .font(.neueHeadline)
                            .foregroundStyle(.white)
                        Text("Floor Plan")
                            .font(.neueCaption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: .circle)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                Spacer()
            }
        }
    }
}
