import SwiftUI

struct AdminSelectionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let selection: BuildSpecSelection
    let colourSelection: BuildColourSelection?
    let specTier: String
    var onApprove: (String) -> Void
    var onAddNotes: (String, String) -> Void
    var onSetUpgradeCost: (String, Double?, String?) -> Void

    @State private var adminNotes: String = ""
    @State private var upgradeCostText: String = ""
    @State private var upgradeCostNote: String = ""
    @State private var showApproveConfirm = false

    private var catalog: CatalogDataManager { CatalogDataManager.shared }

    private var resolvedColourOption: (category: ColourCategory, option: ColourOption)? {
        guard let cs = colourSelection else { return nil }
        guard let cat = catalog.allColourCategories.first(where: { $0.id == cs.colourCategoryId }) else { return nil }
        guard let opt = cat.options.first(where: { $0.id == cs.colourOptionId }) else { return nil }
        return (category: cat, option: opt)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    itemHeader
                    statusSection
                    detailsSection

                    if let resolved = resolvedColourOption {
                        colourSection(resolved)
                    }

                    notesSection
                    upgradeSection
                    actionsSection
                }
                .padding(20)
            }
            .background(AVIATheme.background)
            .navigationTitle("Selection Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.neueSubheadlineMedium)
                        .tint(AVIATheme.timelessBrown)
                }
            }
            .onAppear {
                adminNotes = selection.adminNotes ?? ""
                if let cost = selection.upgradeCost {
                    upgradeCostText = String(format: "%.2f", cost)
                }
                upgradeCostNote = selection.upgradeCostNote ?? ""
            }
            .alert("Approve Item", isPresented: $showApproveConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Approve") {
                    onApprove(selection.id)
                    dismiss()
                }
            } message: {
                Text("Mark \"\(selection.snapshotName)\" as approved?")
            }
        }
        .presentationDetents([.large])
        .presentationBackground(AVIATheme.background)
    }

    private var itemHeader: some View {
        HStack(spacing: 14) {
            if let url = selection.snapshotImageURL, !url.isEmpty, let imgURL = URL(string: url) {
                Color(.secondarySystemBackground)
                    .frame(width: 72, height: 72)
                    .overlay {
                        AsyncImage(url: imgURL) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Image(systemName: "photo")
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AVIATheme.surfaceElevated)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: "cube.box")
                            .font(.system(size: 24))
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(selection.snapshotName)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(selection.snapshotCategoryName)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                selectionTypeBadge
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 11))
    }

    @ViewBuilder
    private var selectionTypeBadge: some View {
        let (label, color): (String, Color) = switch selection.selectionType {
        case .included: ("Included", AVIATheme.success)
        case .upgradeDraft: ("Upgrade Draft", AVIATheme.textTertiary)
        case .upgradeRequested: ("Upgrade Requested", AVIATheme.warning)
        case .upgradeCosted: ("Upgrade Costed", AVIATheme.accent)
        case .upgradeAccepted: ("Upgrade Accepted", AVIATheme.heritageBlue)
        case .upgradeDeclined: ("Upgrade Declined", AVIATheme.textTertiary)
        case .upgradeApproved: ("Upgrade Approved", AVIATheme.success)
        case .substituted: ("Substituted", AVIATheme.heritageBlue)
        case .removed: ("Removed", AVIATheme.destructive)
        }
        Text(label.uppercased())
            .font(.neueCorpMedium(8))
            .kerning(0.5)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private var statusSection: some View {
        BentoCard(cornerRadius: 11) {
            VStack(spacing: 12) {
                HStack {
                    Text("STATUS")
                        .font(.neueCaption2Medium)
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Spacer()
                }

                HStack(spacing: 16) {
                    statusItem(
                        icon: "person.fill.checkmark",
                        label: "Client",
                        confirmed: selection.clientConfirmed,
                        date: selection.clientConfirmedAt
                    )
                    Spacer()
                    statusItem(
                        icon: "shield.checkered",
                        label: "Admin",
                        confirmed: selection.adminConfirmed,
                        date: selection.adminConfirmedAt
                    )
                }
            }
            .padding(16)
        }
    }

    private func statusItem(icon: String, label: String, confirmed: Bool, date: Date?) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.neueCorp(14))
                .foregroundStyle(confirmed ? AVIATheme.success : AVIATheme.textTertiary)
                .frame(width: 32, height: 32)
                .background((confirmed ? AVIATheme.success : AVIATheme.textTertiary).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                if confirmed, let date {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                } else {
                    Text(confirmed ? "Confirmed" : "Pending")
                        .font(.neueCaption2)
                        .foregroundStyle(confirmed ? AVIATheme.success : AVIATheme.textTertiary)
                }
            }
        }
    }

    private var detailsSection: some View {
        BentoCard(cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("DESCRIPTION")
                        .font(.neueCaption2Medium)
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Spacer()
                }
                Text(selection.snapshotDescription)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)

                Divider().foregroundStyle(AVIATheme.surfaceBorder)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spec Tier")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text(selection.specTier.capitalized)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Overall Status")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text(selection.status.displayLabel)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                    }
                }
            }
            .padding(16)
        }
    }

    private func colourSection(_ resolved: (category: ColourCategory, option: ColourOption)) -> some View {
        BentoCard(cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("COLOUR SELECTION")
                        .font(.neueCaption2Medium)
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Spacer()
                    if let cs = colourSelection {
                        Text(cs.selectionStatus.rawValue.capitalized)
                            .font(.neueCorpMedium(8))
                            .foregroundStyle(cs.selectionStatus == .approved ? AVIATheme.success : AVIATheme.warning)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background((cs.selectionStatus == .approved ? AVIATheme.success : AVIATheme.warning).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 12) {
                    if let imgURL = resolved.option.imageURL, !imgURL.isEmpty {
                        Color(.secondarySystemBackground)
                            .frame(width: 48, height: 48)
                            .overlay {
                                AsyncImage(url: URL(string: imgURL)) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    }
                                }
                                .allowsHitTesting(false)
                            }
                            .clipShape(.rect(cornerRadius: 6))
                    } else {
                        Circle()
                            .fill(Color(hex: resolved.option.hexColor))
                            .frame(width: 40, height: 40)
                            .overlay { Circle().stroke(AVIATheme.surfaceBorder, lineWidth: 1) }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(resolved.category.name)
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text(resolved.option.name)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        if let brand = resolved.option.brand, !brand.isEmpty {
                            Text(brand)
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var notesSection: some View {
        BentoCard(cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("NOTES")
                        .font(.neueCaption2Medium)
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Spacer()
                }

                if let clientNotes = selection.clientNotes, !clientNotes.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "person.fill")
                            .font(.neueCorp(10))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Client Notes")
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.textTertiary)
                            Text(clientNotes)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AVIATheme.timelessBrown.opacity(0.06))
                    .clipShape(.rect(cornerRadius: 6))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Admin Notes")
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textTertiary)
                    TextField("Add admin notes...", text: $adminNotes, axis: .vertical)
                        .font(.neueCaption)
                        .lineLimit(3...6)
                        .padding(10)
                        .background(AVIATheme.surfaceElevated)
                        .clipShape(.rect(cornerRadius: 6))
                    HStack {
                        Spacer()
                        Button("Save Notes") {
                            onAddNotes(selection.id, adminNotes)
                        }
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var upgradeSection: some View {
        if selection.selectionType == .upgradeRequested {
            BentoCard(cornerRadius: 11) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("SET UPGRADE COST")
                            .font(.neueCaption2Medium)
                            .kerning(1.0)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Spacer()
                    }

                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            Text("$")
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textSecondary)
                            TextField("0.00", text: $upgradeCostText)
                                .keyboardType(.decimalPad)
                                .font(.neueCaption)
                        }
                        .padding(10)
                        .background(AVIATheme.surfaceElevated)
                        .clipShape(.rect(cornerRadius: 6))
                        .frame(width: 120)

                        TextField("Cost note...", text: $upgradeCostNote)
                            .font(.neueCaption)
                            .padding(10)
                            .background(AVIATheme.surfaceElevated)
                            .clipShape(.rect(cornerRadius: 6))
                    }

                    HStack {
                        Spacer()
                        Button("Set Upgrade Cost") {
                            let cost = Double(upgradeCostText)
                            onSetUpgradeCost(selection.id, cost, upgradeCostNote.isEmpty ? nil : upgradeCostNote)
                            dismiss()
                        }
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(Capsule())
                    }
                }
                .padding(16)
            }
        } else if selection.selectionType == .upgradeCosted {
            BentoCard(cornerRadius: 11) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("UPGRADE COST")
                            .font(.neueCaption2Medium)
                            .kerning(1.0)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Spacer()
                    }
                    if let cost = selection.upgradeCost {
                        Text(String(format: "$%.2f", cost))
                            .font(.neueCorpMedium(20))
                            .foregroundStyle(AVIATheme.textPrimary)
                    }
                    if let note = selection.upgradeCostNote, !note.isEmpty {
                        Text(note)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass")
                            .font(.neueCorp(10))
                        Text("Awaiting client response")
                            .font(.neueCaptionMedium)
                    }
                    .foregroundStyle(AVIATheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AVIATheme.accent.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))

                    reviseCostFields
                }
                .padding(16)
            }
        } else if selection.selectionType == .upgradeAccepted || selection.selectionType == .upgradeApproved {
            BentoCard(cornerRadius: 11) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("UPGRADE COST")
                            .font(.neueCaption2Medium)
                            .kerning(1.0)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Spacer()
                    }
                    if let cost = selection.upgradeCost {
                        Text(String(format: "$%.2f", cost))
                            .font(.neueCorpMedium(20))
                            .foregroundStyle(AVIATheme.textPrimary)
                    }
                    if let note = selection.upgradeCostNote, !note.isEmpty {
                        Text(note)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: selection.selectionType == .upgradeApproved ? "checkmark.circle.fill" : "hand.thumbsup.fill")
                            .font(.neueCorp(10))
                        Text(selection.selectionType == .upgradeApproved ? "Upgrade approved" : "Client accepted — awaiting your final confirmation")
                            .font(.neueCaptionMedium)
                    }
                    .foregroundStyle(selection.selectionType == .upgradeApproved ? AVIATheme.success : AVIATheme.heritageBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background((selection.selectionType == .upgradeApproved ? AVIATheme.success : AVIATheme.heritageBlue).opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))

                    reviseCostFields
                }
                .padding(16)
            }
        } else if selection.selectionType == .upgradeDeclined {
            BentoCard(cornerRadius: 11) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("UPGRADE")
                            .font(.neueCaption2Medium)
                            .kerning(1.0)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Spacer()
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.neueCorp(10))
                        Text("Declined by client")
                            .font(.neueCaptionMedium)
                    }
                    .foregroundStyle(AVIATheme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AVIATheme.textTertiary.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 8))
                }
                .padding(16)
            }
        }
    }

    private var reviseCostFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                .padding(.vertical, 4)

            Text("REVISE COST")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)

            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Text("$")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textSecondary)
                    TextField("0.00", text: $upgradeCostText)
                        .keyboardType(.decimalPad)
                        .font(.neueCaption)
                }
                .padding(10)
                .background(AVIATheme.surfaceElevated)
                .clipShape(.rect(cornerRadius: 6))
                .frame(width: 120)

                TextField("Cost note...", text: $upgradeCostNote)
                    .font(.neueCaption)
                    .padding(10)
                    .background(AVIATheme.surfaceElevated)
                    .clipShape(.rect(cornerRadius: 6))
            }

            HStack {
                Spacer()
                Button("Update Cost & Re-send to Client") {
                    let cost = Double(upgradeCostText)
                    onSetUpgradeCost(selection.id, cost, upgradeCostNote.isEmpty ? nil : upgradeCostNote)
                    dismiss()
                }
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(AVIATheme.accent)
                .clipShape(Capsule())
            }

            Text("Changing the cost will reset the client\u{2019}s response. They will need to accept or decline the updated amount.")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
    }

    private var actionsSection: some View {
        VStack(spacing: 10) {
            if selection.selectionType == .upgradeRequested {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(AVIATheme.warning)
                    Text("Set an upgrade cost above to proceed")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.warning)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(AVIATheme.warning.opacity(0.08))
                .clipShape(.rect(cornerRadius: 11))
            } else if selection.selectionType == .upgradeCosted {
                HStack(spacing: 8) {
                    Image(systemName: "hourglass")
                        .foregroundStyle(AVIATheme.accent)
                    Text("Awaiting client response")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.accent)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(AVIATheme.accent.opacity(0.08))
                .clipShape(.rect(cornerRadius: 11))
            } else if selection.selectionType == .upgradeAccepted {
                Button {
                    showApproveConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Final Confirm Upgrade")
                    }
                    .font(.neueSubheadlineMedium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .background(AVIATheme.timelessBrown)
                    .clipShape(.rect(cornerRadius: 11))
                }
            } else if selection.selectionType == .upgradeDeclined {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AVIATheme.textTertiary)
                    Text("Declined by client — no action needed")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(AVIATheme.textTertiary.opacity(0.08))
                .clipShape(.rect(cornerRadius: 11))
            } else if !selection.adminConfirmed {
                Button {
                    showApproveConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Approve This Item")
                    }
                    .font(.neueSubheadlineMedium)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .background(AVIATheme.timelessBrown)
                    .clipShape(.rect(cornerRadius: 11))
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(AVIATheme.success)
                    Text("This item has been approved")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.success)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(AVIATheme.success.opacity(0.08))
                .clipShape(.rect(cornerRadius: 11))
            }
        }
    }
}
