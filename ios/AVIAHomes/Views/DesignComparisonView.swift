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
                    descriptionSection
                    keyRoomsAndDimensionsSection
                    specificationsSection
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
            AVIATheme.timelessBrown
                .aspectRatio(3 / 4, contentMode: .fit)
                .overlay {
                    AsyncImage(url: URL(string: url)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fit).padding(8)
                        } else if phase.error != nil {
                            Image(systemName: "rectangle.split.2x2")
                                .font(.neueCorpMedium(28))
                                .foregroundStyle(AVIATheme.aviaWhite.opacity(0.4))
                        } else {
                            ProgressView().tint(AVIATheme.aviaWhite)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    Text(design.name)
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AVIATheme.timelessBrown.opacity(0.6), in: .capsule)
                        .padding(8)
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .padding(6)
                        .background(AVIATheme.aviaWhite.opacity(0.95), in: .circle)
                        .padding(8)
                }
                .clipShape(.rect(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("DESCRIPTION")

            HStack(alignment: .top, spacing: 10) {
                descriptionCard(design: designA)
                descriptionCard(design: designB)
            }
        }
    }

    private func descriptionCard(design: HomeDesign) -> some View {
        BentoCard(cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 8) {
                Text(design.name)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.timelessBrown)

                if !design.priceFrom.isEmpty {
                    Text("From \(design.priceFrom)")
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textSecondary)
                }

                Text(design.description.isEmpty ? "No description available." : design.description)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }

    // MARK: - Key Rooms & Dimensions Section

    private var keyRoomsAndDimensionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("KEY ROOMS & DIMENSIONS")

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
                    rowDivider
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

    // MARK: - Specifications Section

    private var specificationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("SPECIFICATIONS")

            HStack(alignment: .top, spacing: 10) {
                specificationsCard(design: designA)
                specificationsCard(design: designB)
            }
        }
    }

    private func specificationsCard(design: HomeDesign) -> some View {
        BentoCard(cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 12) {
                Text(design.name)
                    .font(.neueCaption2Medium)
                    .kerning(0.6)
                    .foregroundStyle(AVIATheme.timelessBrown)

                if !design.roomHighlights.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Room Highlights")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AVIATheme.textTertiary)
                        ForEach(design.roomHighlights, id: \.self) { item in
                            specBullet(item)
                        }
                    }
                }

                if !design.inclusions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Inclusions")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AVIATheme.textTertiary)
                        ForEach(design.inclusions, id: \.self) { item in
                            specBullet(item)
                        }
                    }
                }

                if design.roomHighlights.isEmpty && design.inclusions.isEmpty {
                    Text("No specifications listed.")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }

    private func specBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AVIATheme.timelessBrown)
                .padding(.top, 2)
            Text(text)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
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
