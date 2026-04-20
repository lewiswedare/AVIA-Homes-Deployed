import SwiftUI

/// Admin-facing card for a pending spec range upgrade. Handles the new
/// "price it → send back to client → final approve" flow so it mirrors the
/// per-item spec upgrade experience.
struct RangeUpgradeAdminCard: View {
    let req: BuildRangeUpgradeRequest
    @Bindable var viewModel: BuildSpecViewModel

    @State private var costText: String = ""
    @State private var note: String = ""

    var body: some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.up.forward.circle.fill")
                        .font(.neueCorpMedium(18))
                        .foregroundStyle(headerColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(req.fromTier.capitalized) → \(req.toTier.capitalized)")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text(req.status.displayLabel)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(AVIATheme.formatCost(req.cost))
                            .font(.neueCorpMedium(16))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text(req.status == .pendingAdminCost ? "Estimate" : "Confirmed")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }

                if let notes = req.clientNotes, !notes.isEmpty {
                    Text(notes)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                }

                switch req.status {
                case .pendingAdminCost:
                    pricingEditor
                case .pendingClient:
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass")
                            .font(.neueCorp(10))
                        Text("Cost confirmed. Waiting for client to accept or decline.")
                            .font(.neueCaption2)
                    }
                    .foregroundStyle(AVIATheme.accent)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AVIATheme.accent.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 10))

                    revisePricingEditor
                case .clientAccepted:
                    finalApprovalButtons
                default:
                    EmptyView()
                }
            }
            .padding(14)
        }
        .onAppear {
            costText = String(format: "%.2f", req.cost)
            note = req.adminNotes ?? ""
        }
    }

    private var headerColor: Color {
        switch req.status {
        case .pendingAdminCost: AVIATheme.accent
        case .pendingClient: AVIATheme.warning
        case .clientAccepted: AVIATheme.heritageBlue
        default: AVIATheme.timelessBrown
        }
    }

    private var pricingEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONFIRM FINAL COST")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Text("$")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textSecondary)
                    TextField("0.00", text: $costText)
                        .keyboardType(.decimalPad)
                        .font(.neueCaption)
                }
                .padding(10)
                .background(AVIATheme.surfaceElevated)
                .clipShape(.rect(cornerRadius: 8))
                .frame(width: 120)

                TextField("Cost note (optional)...", text: $note)
                    .font(.neueCaption)
                    .padding(10)
                    .background(AVIATheme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: 8))
            }

            HStack(spacing: 10) {
                Button {
                    let cost = Double(costText) ?? req.cost
                    Task { await viewModel.adminConfirmRangeUpgradeCost(requestId: req.id, cost: cost, note: note.isEmpty ? nil : note) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane.fill")
                        Text("Confirm & Send to Client")
                    }
                    .font(.neueCaption2Medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .background(AVIATheme.timelessBrown)
                    .clipShape(Capsule())
                }

                Button {
                    Task { await viewModel.adminRejectRangeUpgrade(requestId: req.id) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("Remove")
                    }
                    .font(.neueCaption2Medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundStyle(AVIATheme.destructive)
                    .background(AVIATheme.destructive.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var revisePricingEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REVISE COST")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Text("$")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textSecondary)
                    TextField("0.00", text: $costText)
                        .keyboardType(.decimalPad)
                        .font(.neueCaption)
                }
                .padding(10)
                .background(AVIATheme.surfaceElevated)
                .clipShape(.rect(cornerRadius: 8))
                .frame(width: 120)

                TextField("Cost note (optional)...", text: $note)
                    .font(.neueCaption)
                    .padding(10)
                    .background(AVIATheme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: 8))
            }

            Button {
                let cost = Double(costText) ?? req.cost
                Task { await viewModel.adminConfirmRangeUpgradeCost(requestId: req.id, cost: cost, note: note.isEmpty ? nil : note) }
            } label: {
                Text("Update Cost & Re-send")
                    .font(.neueCaption2Medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .background(AVIATheme.accent)
                    .clipShape(Capsule())
            }

            Text("Changing the cost resets the client's response.")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
    }

    private var finalApprovalButtons: some View {
        HStack(spacing: 10) {
            Button {
                Task { await viewModel.adminApproveRangeUpgrade(requestId: req.id) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Approve & Apply")
                }
                .font(.neueCaption2Medium)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .foregroundStyle(AVIATheme.aviaWhite)
                .background(AVIATheme.timelessBrown)
                .clipShape(Capsule())
            }

            Button {
                Task { await viewModel.adminRejectRangeUpgrade(requestId: req.id) }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("Remove")
                }
                .font(.neueCaption2Medium)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .foregroundStyle(AVIATheme.destructive)
                .background(AVIATheme.destructive.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }
}

/// Admin-facing card for a pending colour upgrade. Handles the new
/// "price it → send back to client → final approve" flow.
struct ColourUpgradeAdminCard: View {
    let cs: BuildColourSelection
    let specName: String
    let resolved: (catName: String, optName: String, hex: String, imageURL: String?)?
    @Bindable var viewModel: BuildSpecViewModel

    @State private var costText: String = ""
    @State private var note: String = ""

    var body: some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    if let r = resolved {
                        Circle()
                            .fill(Color(hex: r.hex))
                            .frame(width: 28, height: 28)
                            .overlay { Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(resolved?.optName ?? cs.colourOptionId)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("\(specName) • \(resolved?.catName ?? cs.colourCategoryId) • \(cs.selectionStatus.displayLabel)")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Spacer()
                    Text(AVIATheme.formatCost(cs.cost ?? 0))
                        .font(.neueCorpMedium(16))
                        .foregroundStyle(AVIATheme.timelessBrown)
                }

                switch cs.selectionStatus {
                case .upgradeRequested:
                    pricingEditor
                case .upgradePendingClient:
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass")
                            .font(.neueCorp(10))
                        Text("Cost confirmed. Waiting for client to accept or decline.")
                            .font(.neueCaption2)
                    }
                    .foregroundStyle(AVIATheme.accent)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AVIATheme.accent.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 10))

                    revisePricingEditor
                case .upgradeAcceptedByClient:
                    finalApprovalButtons
                default:
                    EmptyView()
                }
            }
            .padding(14)
        }
        .onAppear {
            costText = String(format: "%.2f", cs.cost ?? 0)
            note = cs.adminNotes ?? ""
        }
    }

    private var pricingEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CONFIRM FINAL COST")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Text("$")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textSecondary)
                    TextField("0.00", text: $costText)
                        .keyboardType(.decimalPad)
                        .font(.neueCaption)
                }
                .padding(10)
                .background(AVIATheme.surfaceElevated)
                .clipShape(.rect(cornerRadius: 8))
                .frame(width: 120)

                TextField("Cost note (optional)...", text: $note)
                    .font(.neueCaption)
                    .padding(10)
                    .background(AVIATheme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: 8))
            }

            HStack(spacing: 10) {
                Button {
                    let cost = Double(costText) ?? (cs.cost ?? 0)
                    viewModel.adminConfirmColourUpgradeCost(selectionId: cs.id, cost: cost, note: note.isEmpty ? nil : note)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "paperplane.fill")
                        Text("Confirm & Send to Client")
                    }
                    .font(.neueCaption2Medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .background(AVIATheme.timelessBrown)
                    .clipShape(Capsule())
                }

                Button {
                    viewModel.adminRejectColourUpgrade(selectionId: cs.id)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                        Text("Remove")
                    }
                    .font(.neueCaption2Medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundStyle(AVIATheme.destructive)
                    .background(AVIATheme.destructive.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var revisePricingEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REVISE COST")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Text("$")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textSecondary)
                    TextField("0.00", text: $costText)
                        .keyboardType(.decimalPad)
                        .font(.neueCaption)
                }
                .padding(10)
                .background(AVIATheme.surfaceElevated)
                .clipShape(.rect(cornerRadius: 8))
                .frame(width: 120)

                TextField("Cost note (optional)...", text: $note)
                    .font(.neueCaption)
                    .padding(10)
                    .background(AVIATheme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: 8))
            }

            Button {
                let cost = Double(costText) ?? (cs.cost ?? 0)
                viewModel.adminConfirmColourUpgradeCost(selectionId: cs.id, cost: cost, note: note.isEmpty ? nil : note)
            } label: {
                Text("Update Cost & Re-send")
                    .font(.neueCaption2Medium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .background(AVIATheme.accent)
                    .clipShape(Capsule())
            }

            Text("Changing the cost resets the client's response.")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
    }

    private var finalApprovalButtons: some View {
        HStack(spacing: 10) {
            Button {
                viewModel.adminApproveColourUpgrade(selectionId: cs.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Approve")
                }
                .font(.neueCaption2Medium)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .foregroundStyle(AVIATheme.aviaWhite)
                .background(AVIATheme.timelessBrown)
                .clipShape(Capsule())
            }

            Button {
                viewModel.adminRejectColourUpgrade(selectionId: cs.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                    Text("Remove")
                }
                .font(.neueCaption2Medium)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .foregroundStyle(AVIATheme.destructive)
                .background(AVIATheme.destructive.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }
}
