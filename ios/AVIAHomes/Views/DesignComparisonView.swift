import SwiftUI

struct DesignComparisonView: View {
    let designA: HomeDesign
    let designB: HomeDesign
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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
            .navigationDestination(for: HomeDesign.self) { design in
                HomeDesignDetailView(design: design)
            }
        }
    }

    // MARK: - Image Row

    private var imageRow: some View {
        HStack(spacing: 10) {
            designImageCard(design: designA)
            designImageCard(design: designB)
        }
    }

    private func designImageCard(design: HomeDesign) -> some View {
        NavigationLink(value: design) {
            Color(AVIATheme.surfaceElevated)
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
                .clipShape(.rect(cornerRadius: 14))
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("KEY STATS")

            BentoCard(cornerRadius: 16) {
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

            BentoCard(cornerRadius: 16) {
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

            BentoCard(cornerRadius: 16) {
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
