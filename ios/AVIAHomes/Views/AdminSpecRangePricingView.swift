import SwiftUI

struct AdminSpecRangePricingView: View {
    // Single storey costs
    @State private var singleVolosToMessinaCost: String = ""
    @State private var singleVolosToPortobelloCost: String = ""
    @State private var singleMessinaToPortobelloCost: String = ""
    // Double storey costs
    @State private var doubleVolosToMessinaCost: String = ""
    @State private var doubleVolosToPortobelloCost: String = ""
    @State private var doubleMessinaToPortobelloCost: String = ""

    @State private var existingPricing: [UpgradePricing] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var successMessage: String?
    @State private var errorMessage: String?

    private let tierPairs: [(from: String, to: String, label: String)] = [
        ("volos", "messina", "Volos \u{2192} Messina"),
        ("volos", "portobello", "Volos \u{2192} Portobello"),
        ("messina", "portobello", "Messina \u{2192} Portobello"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard

                if isLoading {
                    ProgressView()
                        .tint(AVIATheme.timelessBrown)
                        .padding(.vertical, 40)
                } else {
                    singleStoreyPricingCard
                    doubleStoreyPricingCard
                    saveButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("Spec Range Pricing")
        .navigationBarTitleDisplayMode(.large)
        .overlay(alignment: .bottom) { toastOverlay }
        .task { await loadPricing() }
    }

    private var headerCard: some View {
        BentoCard(cornerRadius: 13) {
            HStack(spacing: 14) {
                Image(systemName: "dollarsign.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.neueCorpMedium(18))
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 44, height: 44)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Full Spec Range Upgrade Pricing")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Set the cost for clients to upgrade their entire spec range from one tier to another. Pricing varies by single or double storey homes.")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineLimit(3)
                }
                Spacer()
            }
            .padding(16)
        }
    }

    private var singleStoreyPricingCard: some View {
        BentoCard(cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "building")
                        .font(.neueCorpMedium(12))
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("SINGLE STOREY")
                        .font(.neueCorpMedium(9))
                        .kerning(0.5)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .padding(.horizontal, 14)

                VStack(spacing: 10) {
                    fullRangeCostField(
                        label: "Full upgrade Volos \u{2192} Messina",
                        text: $singleVolosToMessinaCost,
                        fromColor: AVIATheme.timelessBrown,
                        toColor: AVIATheme.warning
                    )
                    fullRangeCostField(
                        label: "Full upgrade Volos \u{2192} Portobello",
                        text: $singleVolosToPortobelloCost,
                        fromColor: AVIATheme.timelessBrown,
                        toColor: AVIATheme.heritageBlue
                    )
                    fullRangeCostField(
                        label: "Full upgrade Messina \u{2192} Portobello",
                        text: $singleMessinaToPortobelloCost,
                        fromColor: AVIATheme.warning,
                        toColor: AVIATheme.heritageBlue
                    )
                }
                .padding(.horizontal, 14)
            }
            .padding(.vertical, 14)
        }
    }

    private var doubleStoreyPricingCard: some View {
        BentoCard(cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "building.2")
                        .font(.neueCorpMedium(12))
                        .foregroundStyle(AVIATheme.heritageBlue)
                    Text("DOUBLE STOREY")
                        .font(.neueCorpMedium(9))
                        .kerning(0.5)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .padding(.horizontal, 14)

                VStack(spacing: 10) {
                    fullRangeCostField(
                        label: "Full upgrade Volos \u{2192} Messina",
                        text: $doubleVolosToMessinaCost,
                        fromColor: AVIATheme.timelessBrown,
                        toColor: AVIATheme.warning
                    )
                    fullRangeCostField(
                        label: "Full upgrade Volos \u{2192} Portobello",
                        text: $doubleVolosToPortobelloCost,
                        fromColor: AVIATheme.timelessBrown,
                        toColor: AVIATheme.heritageBlue
                    )
                    fullRangeCostField(
                        label: "Full upgrade Messina \u{2192} Portobello",
                        text: $doubleMessinaToPortobelloCost,
                        fromColor: AVIATheme.warning,
                        toColor: AVIATheme.heritageBlue
                    )
                }
                .padding(.horizontal, 14)
            }
            .padding(.vertical, 14)
        }
    }

    private func fullRangeCostField(label: String, text: Binding<String>, fromColor: Color, toColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(fromColor).frame(width: 8, height: 8)
                Text("\u{2192}")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                Circle().fill(toColor).frame(width: 8, height: 8)
                Text(label)
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textSecondary)
            }

            HStack(spacing: 4) {
                Text("$")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textTertiary)
                TextField("0.00", text: text)
                    .font(.neueCaption)
                    .keyboardType(.decimalPad)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AVIATheme.surfaceElevated)
            .clipShape(.rect(cornerRadius: 6))
        }
    }

    private var saveButton: some View {
        Button {
            Task { await savePricing() }
        } label: {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView()
                        .tint(AVIATheme.aviaWhite)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text("Save Pricing")
            }
            .font(.neueSubheadlineMedium)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(AVIATheme.aviaWhite)
            .background(AVIATheme.primaryGradient)
            .clipShape(.rect(cornerRadius: 11))
        }
        .disabled(isSaving)
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = successMessage {
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
                        withAnimation { successMessage = nil }
                    }
                }
        }
        if let msg = errorMessage {
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
                        withAnimation { errorMessage = nil }
                    }
                }
        }
    }

    private func loadPricing() async {
        isLoading = true
        let pricing = await SupabaseService.shared.fetchFullRangeUpgradePricing()
        existingPricing = pricing

        for item in pricing where item.isActive {
            let cost = String(format: "%.2f", item.cost)
            let storeyType = item.storeyType ?? "single"
            switch (storeyType, item.fromTier, item.toTier) {
            case ("single", "volos", "messina"):
                singleVolosToMessinaCost = cost
            case ("single", "volos", "portobello"):
                singleVolosToPortobelloCost = cost
            case ("single", "messina", "portobello"):
                singleMessinaToPortobelloCost = cost
            case ("double", "volos", "messina"):
                doubleVolosToMessinaCost = cost
            case ("double", "volos", "portobello"):
                doubleVolosToPortobelloCost = cost
            case ("double", "messina", "portobello"):
                doubleMessinaToPortobelloCost = cost
            default:
                break
            }
        }
        isLoading = false
    }

    private func savePricing() async {
        isSaving = true
        errorMessage = nil

        let costs: [(from: String, to: String, storeyType: String, value: String)] = [
            ("volos", "messina", "single", singleVolosToMessinaCost),
            ("volos", "portobello", "single", singleVolosToPortobelloCost),
            ("messina", "portobello", "single", singleMessinaToPortobelloCost),
            ("volos", "messina", "double", doubleVolosToMessinaCost),
            ("volos", "portobello", "double", doubleVolosToPortobelloCost),
            ("messina", "portobello", "double", doubleMessinaToPortobelloCost),
        ]

        var allSuccess = true
        for entry in costs {
            guard let costValue = Double(entry.value), costValue > 0 else { continue }

            let existingId = existingPricing.first {
                $0.fromTier == entry.from && $0.toTier == entry.to && ($0.storeyType ?? "single") == entry.storeyType
            }?.id ?? UUID().uuidString

            let row = UpgradePricingRow(
                id: existingId,
                spec_item_id: nil,
                colour_category_id: nil,
                colour_option_id: nil,
                from_tier: entry.from,
                to_tier: entry.to,
                cost: costValue,
                description: "Full spec range upgrade \(entry.from.capitalized) to \(entry.to.capitalized) (\(entry.storeyType) storey)",
                is_active: true,
                created_at: nil,
                updated_at: ISO8601DateFormatter().string(from: .now),
                storey_type: entry.storeyType
            )

            let success = await SupabaseService.shared.upsertUpgradePricing(row)
            if !success { allSuccess = false }
        }

        if allSuccess {
            withAnimation { successMessage = "Spec range pricing saved" }
        } else {
            withAnimation { errorMessage = "Failed to save some pricing entries" }
        }

        await loadPricing()
        isSaving = false
    }
}
