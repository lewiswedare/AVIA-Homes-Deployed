import SwiftUI

struct DesignComparisonView: View {
    let designA: HomeDesign
    let designB: HomeDesign
    @Environment(\.dismiss) private var dismiss
    @State private var zoomedFloorplan: ZoomedFloorplan?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    floorPlansHeader

                    HStack(alignment: .top, spacing: 12) {
                        designColumn(design: designA)
                        designColumn(design: designB)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
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

    // MARK: - Top Header

    private var floorPlansHeader: some View {
        HStack {
            sectionHeader("FLOOR PLANS")
            Spacer()
            Label("Tap to zoom", systemImage: "arrow.up.left.and.arrow.down.right")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
    }

    // MARK: - Per-Design Column

    private func designColumn(design: HomeDesign) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            floorplanCard(design: design)

            VStack(alignment: .leading, spacing: 6) {
                Text(design.name)
                    .font(.neueHeadline)
                    .foregroundStyle(AVIATheme.timelessBrown)

                sectionHeader("ABOUT THIS DESIGN")
            }

            descriptionCard(design: design)

            statsChipRow(design: design)
            dimensionsChipRow(design: design)

            sectionHeader("SPECIFICATIONS")
            specificationsTable(design: design)

            if !design.floorplanPDFURL.isEmpty {
                floorplanPDFCard(design: design)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Floor Plan Card

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
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .padding(6)
                        .background(AVIATheme.aviaWhite.opacity(0.95), in: .circle)
                        .padding(8)
                }
                .clipShape(.rect(cornerRadius: 13))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Description

    private func descriptionCard(design: HomeDesign) -> some View {
        BentoCard(cornerRadius: 13) {
            Text(design.description.isEmpty ? "No description available." : design.description)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
    }

    // MARK: - Chip Rows

    private func statsChipRow(design: HomeDesign) -> some View {
        BentoCard(cornerRadius: 13) {
            HStack(spacing: 0) {
                statChip(value: "\(design.bedrooms)", label: "Bed")
                statChip(value: "\(design.bathrooms)", label: "Bath")
                statChip(value: "\(design.garages)", label: "Car")
                statChip(value: "\(design.livingAreas)", label: "Living")
            }
            .padding(.vertical, 12)
        }
    }

    private func dimensionsChipRow(design: HomeDesign) -> some View {
        BentoCard(cornerRadius: 13) {
            HStack(spacing: 0) {
                statChip(value: String(format: "%.1fm", design.houseWidth), label: "Width")
                statChip(value: String(format: "%.1fm", design.houseLength), label: "Length")
                statChip(value: "\(Int(design.squareMeters))m²", label: "Total")
                statChip(value: String(format: "%.1fm", design.lotWidth), label: "Lot Min")
            }
            .padding(.vertical, 10)
        }
    }

    private func statChip(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Specifications Table

    private func specificationsTable(design: HomeDesign) -> some View {
        BentoCard(cornerRadius: 13) {
            VStack(spacing: 0) {
                specRow(label: "Total Area", value: String(format: "%.2f m²", design.squareMeters))
                rowDivider
                specRow(label: "House Width", value: String(format: "%.2f m", design.houseWidth))
                rowDivider
                specRow(label: "House Length", value: String(format: "%.2f m", design.houseLength))
                rowDivider
                specRow(label: "Bedrooms", value: "\(design.bedrooms)")
                rowDivider
                specRow(label: "Bathrooms", value: "\(design.bathrooms)")
                rowDivider
                specRow(label: "Living Areas", value: "\(design.livingAreas)")
                rowDivider
                specRow(label: "Garage", value: "\(design.garages)-car")
                rowDivider
                specRow(label: "Storeys", value: design.storeys == 1 ? "Single" : "Double")
                rowDivider
                specRow(label: "Min. Lot Width", value: String(format: "%.1f m", design.lotWidth))
            }
            .padding(.vertical, 4)
        }
    }

    private func specRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            Text(value)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(AVIATheme.surfaceBorder)
            .frame(height: 1)
            .padding(.horizontal, 12)
    }

    // MARK: - Floor Plan PDF Card

    private func floorplanPDFCard(design: HomeDesign) -> some View {
        let pdfImageURL = design.floorplanPDFImageURL.isEmpty ? design.floorplanImageURL : design.floorplanPDFImageURL

        return Group {
            if let url = URL(string: design.floorplanPDFURL) {
                ShareLink(item: url) {
                    Color(.secondarySystemBackground)
                        .frame(height: 160)
                        .overlay {
                            AsyncImage(url: URL(string: pdfImageURL)) { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .blur(radius: design.floorplanPDFImageURL.isEmpty ? 2 : 0)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                        .overlay {
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.15),
                                    Color.black.opacity(0.55),
                                    Color.black.opacity(0.85)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .allowsHitTesting(false)
                        }
                        .clipShape(.rect(cornerRadius: 13))
                        .overlay(alignment: .topLeading) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.richtext.fill")
                                    .font(.system(size: 9, weight: .semibold))
                                Text("PDF")
                                    .font(.neueCorpMedium(9))
                                    .tracking(1.0)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial, in: .capsule)
                            .environment(\.colorScheme, .dark)
                            .padding(10)
                        }
                        .overlay(alignment: .bottomLeading) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Floor Plan")
                                    .font(.neueCorpMedium(15))
                                    .foregroundStyle(.white)
                                Text("Download the full \(design.name) plan")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .lineLimit(2)
                            }
                            .padding(10)
                        }
                        .overlay(alignment: .bottomTrailing) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                Text("Download")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(AVIATheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white, in: .capsule)
                            .padding(10)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.neueCaption2Medium)
            .kerning(1.0)
            .foregroundStyle(AVIATheme.timelessBrown)
            .padding(.leading, 10)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(AVIATheme.timelessBrown)
                    .frame(width: 2.5)
            }
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
