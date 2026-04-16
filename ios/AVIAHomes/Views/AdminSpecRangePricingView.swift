import SwiftUI

struct AdminSpecRangePricingView: View {
    @State private var volosToMessinaCost: String = ""
    @State private var volosToPortobelloCost: String = ""
    @State private var messinaToPortobelloCost: String = ""
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
                        .tint(AVIATheme.teal)
                        .padding(.vertical, 40)
                } else {
                    pricingCard
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
        BentoCard(cornerRadius: 16) {
            HStack(spacing: 14) {
                Image(systemName: "dollarsign.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.neueCorpMedium(18))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(AVIATheme.tealGradient)
                    .clipShape(.rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Full Spec Range Upgrade Pricing")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Set the cost for clients to upgrade their entire spec range from one tier to another. This is separate from individual item upgrades.")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineLimit(3)
                }
                Spacer()
            }
            .padding(16)
        }
    }

    private var pricingCard: some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 16) {
                Text("FULL RANGE UPGRADE COSTS")
                    .font(.neueCorpMedium(9))
                    .kerning(0.5)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .padding(.horizontal, 14)

                Text("These prices apply when a client upgrades their entire spec range at once, rather than individual items.")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .padding(.horizontal, 14)

                VStack(spacing: 10) {
                    fullRangeCostField(
                        label: "Full upgrade Volos \u{2192} Messina",
                        text: $volosToMessinaCost,
                        fromColor: AVIATheme.teal,
                        toColor: AVIATheme.warning
                    )
                    fullRangeCostField(
                        label: "Full upgrade Volos \u{2192} Portobello",
                        text: $volosToPortobelloCost,
                        fromColor: AVIATheme.teal,
                        toColor: Color(hex: "8B5CF6")
                    )
                    fullRangeCostField(
                        label: "Full upgrade Messina \u{2192} Portobello",
                        text: $messinaToPortobelloCost,
                        fromColor: AVIATheme.warning,
                        toColor: Color(hex: "8B5CF6")
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
            .clipShape(.rect(cornerRadius: 8))
        }
    }

    private var saveButton: some View {
        Button {
            Task { await savePricing() }
        } label: {
            HStack(spacing: 8) {
                if isSaving {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                }
                Text("Save Pricing")
            }
            .font(.neueSubheadlineMedium)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundStyle(.white)
            .background(AVIATheme.tealGradient)
            .clipShape(.rect(cornerRadius: 14))
        }
        .disabled(isSaving)
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = successMessage {
            Text(msg)
                .font(.neueCaptionMedium)
                .foregroundStyle(.white)
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
                .foregroundStyle(.white)
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
            switch (item.fromTier, item.toTier) {
            case ("volos", "messina"):
                volosToMessinaCost = cost
            case ("volos", "portobello"):
                volosToPortobelloCost = cost
            case ("messina", "portobello"):
                messinaToPortobelloCost = cost
            default:
                break
            }
        }
        isLoading = false
    }

    private func savePricing() async {
        isSaving = true
        errorMessage = nil

        let costs: [(from: String, to: String, value: String)] = [
            ("volos", "messina", volosToMessinaCost),
            ("volos", "portobello", volosToPortobelloCost),
            ("messina", "portobello", messinaToPortobelloCost),
        ]

        var allSuccess = true
        for entry in costs {
            guard let costValue = Double(entry.value), costValue > 0 else { continue }

            let existingId = existingPricing.first {
                $0.fromTier == entry.from && $0.toTier == entry.to
            }?.id ?? UUID().uuidString

            let row = UpgradePricingRow(
                id: existingId,
                spec_item_id: nil,
                colour_category_id: nil,
                colour_option_id: nil,
                from_tier: entry.from,
                to_tier: entry.to,
                cost: costValue,
                description: "Full spec range upgrade \(entry.from.capitalized) to \(entry.to.capitalized)",
                is_active: true,
                created_at: nil,
                updated_at: ISO8601DateFormatter().string(from: .now)
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
