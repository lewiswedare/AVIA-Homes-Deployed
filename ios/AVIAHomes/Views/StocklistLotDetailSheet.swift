import SwiftUI

struct StocklistLotDetailSheet: View {
    let lot: StocklistItemRow
    let estate: StocklistEstateRow
    let altDesigns: [StocklistAltDesignRow]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    Divider()
                    propertySection
                    Divider()
                    buildSection
                    Divider()
                    pricingSection

                    if !altDesigns.isEmpty {
                        Divider()
                        altDesignsSection
                    }

                    if let terms = estate.deposit_terms, !terms.isEmpty {
                        Divider()
                        depositSection(terms)
                    }

                    if let link = lot.sales_package_link, let url = URL(string: link) {
                        Divider()
                        Link(destination: url) {
                            HStack {
                                Image(systemName: "folder.fill")
                                Text("View Sales Package on Drive")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.teal)
                            .padding()
                            .background(AVIATheme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()
            }
            .background(AVIATheme.background)
            .navigationTitle("Lot \(lot.lot_number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Lot \(lot.lot_number)")
                    .font(.neueCorpMedium(28))
                    .foregroundStyle(AVIATheme.textPrimary)
                statusBadge(lot.status)
            }
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                    .font(.neueCorp(12))
                    .foregroundStyle(AVIATheme.teal)
                Text(estate.name)
                    .font(.neueSubheadline)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
        }
    }

    // MARK: - Property Details

    private var propertySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Property Details")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
            detailRow("Lot", lot.lot_number)
            detailRow("Stage", lot.stage)
            detailRow("Land Size", lot.land_size)
            detailRow("Land Price", lot.land_price)
            detailRow("Registered", lot.registered)
            detailRow("Availability", lot.availability)
            detailRow("Eligibility", lot.owner_occ_investor)
        }
    }

    // MARK: - Build Specifications

    private var buildSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Build Specifications")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
            detailRow("Design & Facade", lot.design_facade)
            detailRow("Build Size", lot.build_size)
            detailRow("Bedrooms", lot.bedrooms)
            detailRow("Bathrooms", lot.bathrooms)
            detailRow("Garages", lot.garages)
            detailRow("Theatre/Media", lot.theatre == "1" ? "Yes" : lot.theatre == "0" ? "No" : nil)
            detailRow("Specification", lot.specification)
        }
    }

    // MARK: - Pricing

    private var pricingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pricing")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
            detailRow("Land Price", lot.land_price)
            detailRow("Build Price", lot.build_price)
            if let pkg = lot.package_price, !pkg.isEmpty {
                HStack {
                    Text("Package Price")
                        .foregroundStyle(AVIATheme.textSecondary)
                    Spacer()
                    Text(pkg)
                        .font(.neueCorpMedium(18))
                        .foregroundStyle(AVIATheme.teal)
                }
            }
        }
    }

    // MARK: - Alternative Designs

    private var altDesignsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alternative Designs")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
            ForEach(altDesigns) { alt in
                VStack(alignment: .leading, spacing: 6) {
                    Text(alt.design_facade)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.teal)
                    HStack(spacing: 12) {
                        if let bs = alt.build_size, !bs.isEmpty {
                            Label(bs, systemImage: "ruler")
                        }
                        if let bed = alt.bedrooms, !bed.isEmpty {
                            Label(bed, systemImage: "bed.double.fill")
                        }
                        if let bath = alt.bathrooms, !bath.isEmpty {
                            Label(bath, systemImage: "shower.fill")
                        }
                        if let gar = alt.garages, !gar.isEmpty {
                            Label(gar, systemImage: "car.fill")
                        }
                        if let th = alt.theatre, !th.isEmpty, th != "0" {
                            Label(th, systemImage: "tv.fill")
                        }
                    }
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)

                    if let bp = alt.build_price, !bp.isEmpty {
                        detailRow("Build Price", bp)
                    }
                    if let pp = alt.package_price, !pp.isEmpty {
                        HStack {
                            Text("Package Price")
                                .foregroundStyle(AVIATheme.textSecondary)
                            Spacer()
                            Text(pp)
                                .font(.neueCorpMedium(16))
                                .foregroundStyle(AVIATheme.teal)
                        }
                    }
                }
                .padding()
                .background(AVIATheme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Deposit Terms

    private func depositSection(_ terms: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Deposit Terms")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textPrimary)
            Text(terms)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Helpers

    private func detailRow(_ label: String, _ value: String?) -> some View {
        Group {
            if let value = value, !value.isEmpty {
                HStack {
                    Text(label)
                        .foregroundStyle(AVIATheme.textSecondary)
                    Spacer()
                    Text(value)
                        .foregroundStyle(AVIATheme.textPrimary)
                }
                .font(.neueCaption)
            }
        }
    }

    private func statusBadge(_ status: String) -> some View {
        Text(status)
            .font(.neueCorpMedium(10))
            .kerning(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor(status))
            .clipShape(Capsule())
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "available": return .green
        case "available (exclusive)": return .purple
        case "eoi": return .orange
        case "on hold": return .gray
        case "coming soon": return .blue
        case "sold": return .red
        default: return AVIATheme.textSecondary
        }
    }
}
