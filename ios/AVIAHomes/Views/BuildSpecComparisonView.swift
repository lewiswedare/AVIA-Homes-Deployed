import SwiftUI

struct BuildSpecItemRow: View {
    let selection: BuildSpecSelection
    let isEditable: Bool
    let isAdmin: Bool
    var onUpgradeRequest: ((String) -> Void)?
    var onAcceptUpgrade: ((String) -> Void)?
    var onDeclineUpgrade: ((String) -> Void)?
    var onAdminApprove: ((String) -> Void)?
    var onAdminNotes: ((String, String) -> Void)?

    @State private var showNotes = false
    @State private var notesText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                if let url = selection.snapshotImageURL, !url.isEmpty, let imgURL = URL(string: url) {
                    Color(.secondarySystemBackground)
                        .frame(width: 56, height: 56)
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
                        .clipShape(.rect(cornerRadius: 6))
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AVIATheme.surfaceElevated)
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "cube.box")
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(selection.snapshotName)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)

                        selectionTypeBadge
                    }

                    Text(selection.snapshotDescription)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineLimit(3)

                    statusIndicator
                }

                Spacer(minLength: 0)
            }

            if let notes = selection.clientNotes, !notes.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble")
                        .font(.neueCorp(9))
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text(notes)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineLimit(2)
                }
                .padding(8)
                .background(AVIATheme.timelessBrown.opacity(0.06))
                .clipShape(.rect(cornerRadius: 6))
            }

            if let notes = selection.adminNotes, !notes.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.shield.checkmark")
                        .font(.neueCorp(9))
                        .foregroundStyle(AVIATheme.heritageBlue)
                    Text(notes)
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineLimit(2)
                }
                .padding(8)
                .background(AVIATheme.heritageBlue.opacity(0.06))
                .clipShape(.rect(cornerRadius: 6))
            }

            if let cost = selection.upgradeCost, (selection.selectionType == .upgradeRequested || selection.selectionType == .upgradeCosted || selection.selectionType == .upgradeAccepted || selection.selectionType == .upgradeApproved) {
                HStack(spacing: 6) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.neueCorp(9))
                        .foregroundStyle(AVIATheme.warning)
                    Text("Upgrade cost: $\(cost, specifier: "%.2f")\(selection.upgradeCostNote.map { " — \($0)" } ?? "")")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .padding(8)
                .background(AVIATheme.warning.opacity(0.06))
                .clipShape(.rect(cornerRadius: 6))
            }

            if isEditable || isAdmin {
                actionButtons
            }

            if showNotes {
                notesEditor
            }
        }
        .padding(14)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 11))
    }

    @ViewBuilder
    private var selectionTypeBadge: some View {
        switch selection.selectionType {
        case .included:
            EmptyView()
        case .upgradeDraft:
            Text("DRAFT")
                .font(.neueCorpMedium(7))
                .foregroundStyle(AVIATheme.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AVIATheme.textTertiary.opacity(0.12))
                .clipShape(Capsule())
        case .upgradeRequested:
            Text("UPGRADE REQ.")
                .font(.neueCorpMedium(7))
                .foregroundStyle(AVIATheme.warning)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AVIATheme.warning.opacity(0.12))
                .clipShape(Capsule())
        case .upgradeCosted:
            Text("COST READY")
                .font(.neueCorpMedium(7))
                .foregroundStyle(AVIATheme.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AVIATheme.accent.opacity(0.12))
                .clipShape(Capsule())
        case .upgradeAccepted:
            Text("ACCEPTED")
                .font(.neueCorpMedium(7))
                .foregroundStyle(AVIATheme.heritageBlue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AVIATheme.heritageBlue.opacity(0.12))
                .clipShape(Capsule())
        case .upgradeDeclined:
            EmptyView()
        case .upgradeApproved:
            Text("UPGRADE OK")
                .font(.neueCorpMedium(7))
                .foregroundStyle(AVIATheme.success)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AVIATheme.success.opacity(0.12))
                .clipShape(Capsule())
        case .substituted:
            Text("SUBSTITUTED")
                .font(.neueCorpMedium(7))
                .foregroundStyle(AVIATheme.heritageBlue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AVIATheme.heritageBlue.opacity(0.12))
                .clipShape(Capsule())
        case .removed:
            Text("REMOVED")
                .font(.neueCorpMedium(7))
                .foregroundStyle(AVIATheme.destructive)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AVIATheme.destructive.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var statusIndicator: some View {
        HStack(spacing: 4) {
            if selection.clientConfirmed {
                Image(systemName: "person.fill.checkmark")
                    .font(.neueCorp(8))
                    .foregroundStyle(AVIATheme.success)
            }
            if selection.adminConfirmed {
                Image(systemName: "shield.checkered")
                    .font(.neueCorp(8))
                    .foregroundStyle(AVIATheme.success)
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 8) {
            if !isAdmin && selection.selectionType == .upgradeCosted {
                HStack(spacing: 8) {
                    Button {
                        onAcceptUpgrade?(selection.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.neueCorp(10))
                            Text("Accept Upgrade")
                                .font(.neueCaption2Medium)
                        }
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AVIATheme.timelessBrown)
                        .clipShape(Capsule())
                    }

                    Button {
                        onDeclineUpgrade?(selection.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle")
                                .font(.neueCorp(10))
                            Text("Decline")
                                .font(.neueCaption2Medium)
                        }
                        .foregroundStyle(AVIATheme.destructive)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AVIATheme.destructive.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }
            } else if !isAdmin && selection.selectionType == .upgradeAccepted {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.neueCorp(10))
                    Text("Awaiting admin confirmation")
                        .font(.neueCaption2Medium)
                }
                .foregroundStyle(AVIATheme.warning)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AVIATheme.warning.opacity(0.1))
                .clipShape(Capsule())
            } else {
                HStack(spacing: 8) {
                    if isEditable && !selection.lockedForClient && selection.selectionType == .included {
                        Button {
                            onUpgradeRequest?(selection.id)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.circle")
                                    .font(.neueCorp(10))
                                Text("Request Upgrade")
                                    .font(.neueCaption2Medium)
                            }
                            .foregroundStyle(AVIATheme.timelessBrown)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AVIATheme.timelessBrown.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }

                    if isEditable && !selection.lockedForClient {
                        Button {
                            notesText = selection.clientNotes ?? ""
                            showNotes.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "text.bubble")
                                    .font(.neueCorp(10))
                                Text("Notes")
                                    .font(.neueCaption2Medium)
                            }
                            .foregroundStyle(AVIATheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AVIATheme.surfaceElevated)
                            .clipShape(Capsule())
                        }
                    }

                    if isAdmin {
                        Button {
                            onAdminApprove?(selection.id)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle")
                                    .font(.neueCorp(10))
                                Text("Approve")
                                    .font(.neueCaption2Medium)
                            }
                            .foregroundStyle(AVIATheme.success)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AVIATheme.success.opacity(0.1))
                            .clipShape(Capsule())
                        }

                        Button {
                            notesText = selection.adminNotes ?? ""
                            showNotes.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "note.text")
                                    .font(.neueCorp(10))
                                Text("Note")
                                    .font(.neueCaption2Medium)
                            }
                            .foregroundStyle(AVIATheme.heritageBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AVIATheme.heritageBlue.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var notesEditor: some View {
        VStack(spacing: 8) {
            TextField("Add a note...", text: $notesText, axis: .vertical)
                .font(.neueCaption)
                .lineLimit(3...5)
                .padding(10)
                .background(AVIATheme.surfaceElevated)
                .clipShape(.rect(cornerRadius: 6))

            HStack {
                Spacer()
                Button("Save") {
                    if isAdmin {
                        onAdminNotes?(selection.id, notesText)
                    }
                    showNotes = false
                }
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.aviaWhite)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(AVIATheme.primaryGradient)
                .clipShape(Capsule())
            }
        }
    }
}

struct BuildSpecCategorySection: View {
    let categoryName: String
    let items: [BuildSpecSelection]
    let isEditable: Bool
    let isAdmin: Bool
    var onUpgradeRequest: ((String) -> Void)?
    var onAcceptUpgrade: ((String) -> Void)?
    var onDeclineUpgrade: ((String) -> Void)?
    var onAdminApprove: ((String) -> Void)?
    var onAdminNotes: ((String, String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(categoryName.uppercased())
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)
                .padding(.horizontal, 4)

            ForEach(items) { item in
                BuildSpecItemRow(
                    selection: item,
                    isEditable: isEditable,
                    isAdmin: isAdmin,
                    onUpgradeRequest: onUpgradeRequest,
                    onAcceptUpgrade: onAcceptUpgrade,
                    onDeclineUpgrade: onDeclineUpgrade,
                    onAdminApprove: onAdminApprove,
                    onAdminNotes: onAdminNotes
                )
            }
        }
    }
}
