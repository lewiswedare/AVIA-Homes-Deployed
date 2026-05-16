import WidgetKit
import SwiftUI

// MARK: - Timeline

nonisolated struct BuildEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

nonisolated struct BuildProvider: TimelineProvider {
    func placeholder(in context: Context) -> BuildEntry {
        BuildEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (BuildEntry) -> Void) {
        completion(BuildEntry(date: .now, snapshot: WidgetSnapshotStore.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BuildEntry>) -> Void) {
        let entry = BuildEntry(date: .now, snapshot: WidgetSnapshotStore.read())
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Root widget view

struct AVIAHomesWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: BuildProvider.Entry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                AVIAWidgetSmall(snapshot: entry.snapshot)
            case .systemMedium:
                AVIAWidgetMedium(snapshot: entry.snapshot)
            default:
                AVIAWidgetLarge(snapshot: entry.snapshot)
            }
        }
        .padding(10)
        .containerBackground(for: .widget) {
            AVIAWidgetBrand.widgetBackdrop
        }
    }
}

// MARK: - Shared helpers (mirror in-app patterns)

private func overallProgressPercent(_ snapshot: WidgetSnapshot) -> Int {
    Int((snapshot.overallProgress * 100).rounded())
}

private func headingIcon(for kind: WidgetSnapshotKind) -> String {
    switch kind {
    case .buildProgress:   return "hammer"
    case .awaitingSpecs:   return "doc.text"
    case .awaitingColours: return "paintpalette"
    case .packageAssigned: return "shippingbox"
    case .noBuild:         return "house"
    }
}

private func smallHeading(_ kind: WidgetSnapshotKind) -> String {
    switch kind {
    case .buildProgress:   return "Your Build"
    case .awaitingSpecs:   return "Selections"
    case .awaitingColours: return "Colours"
    case .packageAssigned: return "Your Package"
    case .noBuild:         return "AVIA Homes"
    }
}

// MARK: - Small  ·  single bento, progress ring + stage

private struct AVIAWidgetSmall: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        AVIABentoCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    AVIAEyebrow(text: smallHeading(snapshot.kind))
                    Spacer()
                    AVIAWordmark(height: 12)
                }

                Spacer(minLength: 0)

                HStack(alignment: .center, spacing: 10) {
                    AVIAProgressRing(
                        progress: snapshot.overallProgress,
                        icon: headingIcon(for: snapshot.kind),
                        diameter: 48
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(overallProgressPercent(snapshot))%")
                            .font(.aviaCorpMedium(22))
                            .foregroundStyle(AVIAWidgetBrand.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(stageLabel)
                            .font(.aviaCorp(10))
                            .foregroundStyle(AVIAWidgetBrand.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                AVIAStepIndicator(
                    total: max(snapshot.totalStages, 1),
                    current: snapshot.completedStages
                )

                Text(footerLabel)
                    .font(.aviaCorp(9))
                    .foregroundStyle(AVIAWidgetBrand.textTertiary)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var stageLabel: String {
        if !snapshot.currentStageName.isEmpty { return snapshot.currentStageName }
        switch snapshot.kind {
        case .awaitingSpecs:   return "Selections pending"
        case .awaitingColours: return "Colours pending"
        case .packageAssigned: return snapshot.package?.title ?? "Your Package"
        case .noBuild:         return "Discover homes"
        case .buildProgress:   return "In progress"
        }
    }

    private var footerLabel: String {
        switch snapshot.kind {
        case .buildProgress:
            return "\(snapshot.completedStages) of \(snapshot.totalStages) stages"
        case .awaitingSpecs:
            return "\(snapshot.specsRemaining) selection\(snapshot.specsRemaining == 1 ? "" : "s") to make"
        case .awaitingColours:
            return "\(snapshot.coloursRemaining) colour\(snapshot.coloursRemaining == 1 ? "" : "s") to choose"
        case .packageAssigned:
            return snapshot.package?.location ?? ""
        case .noBuild:
            return "Tap to explore"
        }
    }
}

// MARK: - Medium  ·  hero strip + 2 bento tiles

private struct AVIAWidgetMedium: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(spacing: 8) {
            heroStrip
            HStack(spacing: 8) {
                progressTile
                rightTile
            }
        }
    }

    private var heroStrip: some View {
        AVIABentoCard(background: .clear) {
            ZStack(alignment: .bottomLeading) {
                Image("hero_facade")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .clipped()

                LinearGradient(
                    colors: [Color.black.opacity(0.55), Color.black.opacity(0.0)],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        AVIAWordmark(height: 12, tint: AVIAWidgetBrand.aviaWhite)
                        Text(snapshot.homeDesign.isEmpty ? "Your AVIA Home" : snapshot.homeDesign)
                            .font(.aviaCorpMedium(13))
                            .foregroundStyle(AVIAWidgetBrand.aviaWhite)
                            .lineLimit(1)
                    }
                    Spacer()
                    if !snapshot.estate.isEmpty {
                        Text(estateLine)
                            .font(.aviaCorp(9))
                            .foregroundStyle(AVIAWidgetBrand.aviaWhite.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(height: 56)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var estateLine: String {
        if snapshot.lotNumber.isEmpty { return snapshot.estate }
        return "Lot \(snapshot.lotNumber) · \(snapshot.estate)"
    }

    private var progressTile: some View {
        AVIABentoCard(cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 6) {
                AVIAEyebrow(text: "Your Journey")
                Spacer(minLength: 0)
                HStack(alignment: .center, spacing: 8) {
                    AVIAProgressRing(
                        progress: snapshot.overallProgress,
                        icon: headingIcon(for: snapshot.kind),
                        diameter: 38,
                        lineWidth: 3
                    )
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(overallProgressPercent(snapshot))%")
                            .font(.aviaCorpMedium(18))
                            .foregroundStyle(AVIAWidgetBrand.textPrimary)
                        Text(snapshot.currentStageName.isEmpty ? "In progress" : snapshot.currentStageName)
                            .font(.aviaCorp(9))
                            .foregroundStyle(AVIAWidgetBrand.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                AVIAStepIndicator(
                    total: max(snapshot.totalStages, 1),
                    current: snapshot.completedStages
                )
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var rightTile: some View {
        if let staff = snapshot.staff, !staff.name.isEmpty {
            AVIABentoCard(cornerRadius: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    AVIAEyebrow(text: "Your Contact")
                    Spacer(minLength: 0)
                    HStack(spacing: 8) {
                        AVIABentoIcon(icon: "person.crop.circle.fill", size: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(staff.name)
                                .font(.aviaCorpMedium(12))
                                .foregroundStyle(AVIAWidgetBrand.textPrimary)
                                .lineLimit(1)
                            Text(staff.roleLabel)
                                .font(.aviaCorp(9))
                                .foregroundStyle(AVIAWidgetBrand.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    Spacer(minLength: 0)
                    Text(snapshot.nextStepTitle.isEmpty ? "Tap to view" : snapshot.nextStepTitle)
                        .font(.aviaCorp(10))
                        .foregroundStyle(AVIAWidgetBrand.textTertiary)
                        .lineLimit(1)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        } else {
            AVIABentoCard(cornerRadius: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    AVIAEyebrow(text: "Next Step")
                    Spacer(minLength: 0)
                    AVIABentoIcon(icon: "arrow.forward", size: 28)
                    Text(snapshot.nextStepTitle.isEmpty ? "You’re all caught up" : snapshot.nextStepTitle)
                        .font(.aviaCorpMedium(12))
                        .foregroundStyle(AVIAWidgetBrand.textPrimary)
                        .lineLimit(2)
                    if !snapshot.nextStepDetail.isEmpty {
                        Text(snapshot.nextStepDetail)
                            .font(.aviaCorp(9))
                            .foregroundStyle(AVIAWidgetBrand.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

// MARK: - Large  ·  AVIA header + hero card + 2×2 bento

private struct AVIAWidgetLarge: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(spacing: 10) {
            headerRow
            heroCard

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                stageTile
                contactTile
                nextStepTile
                packageTile
            }
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: header

    private var headerRow: some View {
        HStack(alignment: .center) {
            AVIAWordmark(height: 16)
            Spacer()
            Text("\(overallProgressPercent(snapshot))% complete")
                .font(.aviaCorpMedium(10))
                .foregroundStyle(AVIAWidgetBrand.timelessBrown)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .overlay(
                    Capsule().stroke(AVIAWidgetBrand.timelessBrown.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: hero

    private var heroCard: some View {
        AVIABentoCard(background: .clear) {
            ZStack(alignment: .bottomLeading) {
                Image("hero_facade")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .clipped()

                LinearGradient(
                    colors: [Color.black.opacity(0.65), Color.black.opacity(0.0)],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.homeDesign.isEmpty ? "Your AVIA Home" : snapshot.homeDesign)
                        .font(.aviaCorpMedium(15))
                        .foregroundStyle(AVIAWidgetBrand.aviaWhite)
                        .lineLimit(1)
                    if !snapshot.estate.isEmpty {
                        Text(estateLine)
                            .font(.aviaCorp(10))
                            .foregroundStyle(AVIAWidgetBrand.aviaWhite.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .frame(height: 72)
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    private var estateLine: String {
        if snapshot.lotNumber.isEmpty { return snapshot.estate }
        return "Lot \(snapshot.lotNumber) · \(snapshot.estate)"
    }

    // MARK: bento tiles

    private var stageTile: some View {
        AVIABentoCard {
            VStack(alignment: .leading, spacing: 6) {
                AVIAEyebrow(text: "Your Journey")
                Spacer(minLength: 0)
                HStack(alignment: .center, spacing: 10) {
                    AVIAProgressRing(
                        progress: snapshot.overallProgress,
                        icon: headingIcon(for: snapshot.kind),
                        diameter: 40,
                        lineWidth: 3.5
                    )
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(overallProgressPercent(snapshot))%")
                            .font(.aviaCorpMedium(20))
                            .foregroundStyle(AVIAWidgetBrand.textPrimary)
                        Text("\(snapshot.completedStages) of \(snapshot.totalStages) stages")
                            .font(.aviaCorp(10))
                            .foregroundStyle(AVIAWidgetBrand.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Text(snapshot.currentStageName.isEmpty ? "In progress" : snapshot.currentStageName)
                    .font(.aviaCorpMedium(12))
                    .foregroundStyle(AVIAWidgetBrand.textPrimary)
                    .lineLimit(1)
                AVIAStepIndicator(
                    total: max(snapshot.totalStages, 1),
                    current: snapshot.completedStages
                )
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var contactTile: some View {
        AVIABentoCard {
            VStack(alignment: .leading, spacing: 6) {
                AVIAEyebrow(text: "Your Contact")
                Spacer(minLength: 0)
                if let staff = snapshot.staff, !staff.name.isEmpty {
                    HStack(spacing: 8) {
                        AVIABentoIcon(icon: "person.crop.circle.fill", size: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(staff.name)
                                .font(.aviaCorpMedium(13))
                                .foregroundStyle(AVIAWidgetBrand.textPrimary)
                                .lineLimit(1)
                            Text(staff.roleLabel)
                                .font(.aviaCorp(10))
                                .foregroundStyle(AVIAWidgetBrand.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        if !staff.phone.isEmpty {
                            ContactChip(icon: "phone.fill")
                        }
                        if !staff.email.isEmpty {
                            ContactChip(icon: "envelope.fill")
                        }
                    }
                } else {
                    AVIABentoIcon(icon: "person.crop.circle", size: 30)
                    Text("Your AVIA team is being assigned")
                        .font(.aviaCorp(11))
                        .foregroundStyle(AVIAWidgetBrand.textSecondary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var nextStepTile: some View {
        AVIABentoCard {
            VStack(alignment: .leading, spacing: 6) {
                AVIAEyebrow(text: "Next Step")
                AVIABentoIcon(icon: "arrow.forward", size: 28)
                Spacer(minLength: 0)
                if snapshot.nextStepTitle.isEmpty {
                    Text("You’re all caught up")
                        .font(.aviaCorpMedium(13))
                        .foregroundStyle(AVIAWidgetBrand.textPrimary)
                        .lineLimit(2)
                } else {
                    Text(snapshot.nextStepTitle)
                        .font(.aviaCorpMedium(13))
                        .foregroundStyle(AVIAWidgetBrand.textPrimary)
                        .lineLimit(2)
                    if !snapshot.nextStepDetail.isEmpty {
                        Text(snapshot.nextStepDetail)
                            .font(.aviaCorp(10))
                            .foregroundStyle(AVIAWidgetBrand.textSecondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var packageTile: some View {
        AVIABentoCard {
            VStack(alignment: .leading, spacing: 6) {
                AVIAEyebrow(text: "Your Package")
                Spacer(minLength: 0)
                if let pkg = snapshot.package {
                    Text(pkg.title)
                        .font(.aviaCorpMedium(13))
                        .foregroundStyle(AVIAWidgetBrand.textPrimary)
                        .lineLimit(1)
                    if !pkg.location.isEmpty {
                        Text(pkg.location)
                            .font(.aviaCorp(10))
                            .foregroundStyle(AVIAWidgetBrand.textSecondary)
                            .lineLimit(1)
                    }
                    HStack(spacing: 10) {
                        PackageBeat(icon: "bed.double.fill", value: "\(pkg.bedrooms)")
                        PackageBeat(icon: "shower.fill", value: "\(pkg.bathrooms)")
                        PackageBeat(icon: "car.fill", value: "\(pkg.garages)")
                    }
                    if !pkg.price.isEmpty {
                        Text(pkg.price)
                            .font(.aviaCorpMedium(12))
                            .foregroundStyle(AVIAWidgetBrand.timelessBrown)
                    }
                } else {
                    AVIABentoIcon(icon: "shippingbox", size: 28)
                    Text("No package assigned yet")
                        .font(.aviaCorp(11))
                        .foregroundStyle(AVIAWidgetBrand.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Small atoms

private struct ContactChip: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.aviaCorpMedium(9))
            .foregroundStyle(AVIAWidgetBrand.timelessBrown)
            .frame(width: 22, height: 22)
            .background(AVIAWidgetBrand.timelessBrown.opacity(0.12))
            .clipShape(Circle())
    }
}

private struct PackageBeat: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.aviaCorpMedium(9))
                .foregroundStyle(AVIAWidgetBrand.timelessBrown)
            Text(value)
                .font(.aviaCorpMedium(11))
                .foregroundStyle(AVIAWidgetBrand.textPrimary)
        }
    }
}

// MARK: - Widget entry point

struct AVIAHomesWidget: Widget {
    let kind: String = "AVIAHomesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BuildProvider()) { entry in
            AVIAHomesWidgetView(entry: entry)
        }
        .configurationDisplayName("AVIA Homes")
        .description("Your build progress, your contact, your next step — at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews

#Preview("Small · build", as: .systemSmall) {
    AVIAHomesWidget()
} timeline: {
    BuildEntry(date: .now, snapshot: .preview)
}

#Preview("Medium · build", as: .systemMedium) {
    AVIAHomesWidget()
} timeline: {
    BuildEntry(date: .now, snapshot: .preview)
}

#Preview("Large · build", as: .systemLarge) {
    AVIAHomesWidget()
} timeline: {
    BuildEntry(date: .now, snapshot: .preview)
}

private extension WidgetSnapshot {
    static let preview = WidgetSnapshot(
        kind: .buildProgress,
        userFirstName: "Lewis",
        homeDesign: "Volos 28",
        estate: "Pacific Cove",
        lotNumber: "412",
        currentStageName: "Frame & Roof",
        currentStageDescription: "Frame inspection scheduled this week.",
        overallProgress: 0.62,
        stageProgress: 0.4,
        totalStages: 7,
        completedStages: 4,
        isAwaitingRegistration: false,
        specsRemaining: 0,
        specsTotal: 24,
        coloursRemaining: 0,
        coloursTotal: 12,
        nextStepTitle: "Sign frame inspection",
        nextStepDetail: "Due Thursday at 4pm",
        staff: WidgetStaffContact(
            name: "Drew Holden",
            roleLabel: "Build Coach",
            phone: "+61 400 000 000",
            email: "drew@aviahomes.com"
        ),
        package: WidgetPackageSummary(
            title: "Volos · House & Land",
            location: "Pacific Cove, QLD",
            homeDesign: "Volos 28",
            price: "$845,000",
            bedrooms: 4,
            bathrooms: 2,
            garages: 2,
            imageURL: nil,
            responseStatus: ""
        ),
        news: [],
        updatedAt: .now
    )
}
