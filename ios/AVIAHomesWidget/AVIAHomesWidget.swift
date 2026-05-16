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
        .containerBackground(for: .widget) {
            AVIAWarmBackdrop()
        }
    }
}

// MARK: - Small

private struct AVIAWidgetSmall: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        AVIAGlassSurface {
            VStack(alignment: .leading, spacing: 8) {
                AVIAEyebrow(text: heading, icon: headingIcon)

                Spacer(minLength: 0)

                Text(primaryValue)
                    .font(.aviaCorpUltralight(40))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)

                Text(primaryLabel)
                    .font(.aviaCorpMedium(11))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)

                AVIAGlassProgressBar(value: progress)

                Text(secondaryLabel)
                    .font(.aviaCorp(10))
                    .foregroundStyle(.white.opacity(0.65))
                    .lineLimit(1)
            }
            .padding(14)
        }
    }

    // MARK: derived

    private var heading: String {
        switch snapshot.kind {
        case .buildProgress:   return "Your Build"
        case .awaitingSpecs:   return "Selections"
        case .awaitingColours: return "Colours"
        case .packageAssigned: return "Your Package"
        case .noBuild:         return "AVIA Homes"
        }
    }

    private var headingIcon: String {
        switch snapshot.kind {
        case .buildProgress:   return "house"
        case .awaitingSpecs:   return "doc.text"
        case .awaitingColours: return "paintpalette"
        case .packageAssigned: return "shippingbox"
        case .noBuild:         return "newspaper"
        }
    }

    private var progress: Double {
        switch snapshot.kind {
        case .buildProgress:
            return snapshot.overallProgress
        case .awaitingSpecs:
            return snapshot.specsTotal == 0 ? 0
                : Double(snapshot.specsTotal - snapshot.specsRemaining) / Double(snapshot.specsTotal)
        case .awaitingColours:
            return snapshot.coloursTotal == 0 ? 0
                : Double(snapshot.coloursTotal - snapshot.coloursRemaining) / Double(snapshot.coloursTotal)
        default:
            return 0
        }
    }

    private var primaryValue: String {
        switch snapshot.kind {
        case .buildProgress:
            return "\(Int((snapshot.overallProgress * 100).rounded()))%"
        case .awaitingSpecs:
            return "\(snapshot.specsRemaining)"
        case .awaitingColours:
            return "\(snapshot.coloursRemaining)"
        case .packageAssigned:
            return snapshot.package?.price ?? ""
        case .noBuild:
            return "AVIA"
        }
    }

    private var primaryLabel: String {
        switch snapshot.kind {
        case .buildProgress:
            return snapshot.currentStageName.isEmpty ? "In progress" : snapshot.currentStageName
        case .awaitingSpecs:
            return snapshot.specsRemaining == 1 ? "Selection to make" : "Selections to make"
        case .awaitingColours:
            return snapshot.coloursRemaining == 1 ? "Colour to choose" : "Colours to choose"
        case .packageAssigned:
            return snapshot.package?.title ?? "House & Land"
        case .noBuild:
            return snapshot.news.first?.title ?? "Discover homes"
        }
    }

    private var secondaryLabel: String {
        switch snapshot.kind {
        case .buildProgress:
            return "\(snapshot.completedStages) of \(snapshot.totalStages) stages"
        case .awaitingSpecs:
            return "Tap to review specs"
        case .awaitingColours:
            return "Tap to choose colours"
        case .packageAssigned:
            return snapshot.package?.location ?? ""
        case .noBuild:
            return "Latest news"
        }
    }
}

// MARK: - Medium

private struct AVIAWidgetMedium: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        AVIAGlassSurface {
            VStack(spacing: 10) {
                // Header row — eyebrow + home design + percent.
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        AVIAEyebrow(text: "Your Build")
                        Text(snapshot.homeDesign.isEmpty ? "AVIA Home" : snapshot.homeDesign)
                            .font(.aviaCorpMedium(17))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if !snapshot.estate.isEmpty {
                            Text("Lot \(snapshot.lotNumber) · \(snapshot.estate)")
                                .font(.aviaCorp(10))
                                .foregroundStyle(.white.opacity(0.65))
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(Int((snapshot.overallProgress * 100).rounded()))%")
                            .font(.aviaCorpUltralight(34))
                            .foregroundStyle(.white)
                        Text("\(snapshot.completedStages)/\(snapshot.totalStages) stages")
                            .font(.aviaCorp(9))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                AVIAGlassProgressBar(value: snapshot.overallProgress)

                // Bento — two tiles: current stage + contact OR next step.
                HStack(spacing: 8) {
                    AVIAGlassTile {
                        VStack(alignment: .leading, spacing: 4) {
                            AVIAEyebrow(text: "Stage", icon: "hammer")
                            Text(snapshot.currentStageName.isEmpty ? "Awaiting start" : snapshot.currentStageName)
                                .font(.aviaCorpMedium(12))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                        }
                    }

                    if let staff = snapshot.staff, !staff.name.isEmpty {
                        AVIAGlassTile {
                            HStack(spacing: 8) {
                                ContactAvatar()
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(staff.name)
                                        .font(.aviaCorpMedium(11))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                    Text(staff.roleLabel)
                                        .font(.aviaCorp(9))
                                        .foregroundStyle(.white.opacity(0.65))
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    } else {
                        AVIAGlassTile {
                            VStack(alignment: .leading, spacing: 4) {
                                AVIAEyebrow(text: "Next", icon: "arrow.forward")
                                Text(snapshot.nextStepTitle.isEmpty ? "Stay tuned" : snapshot.nextStepTitle)
                                    .font(.aviaCorpMedium(12))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
            .padding(14)
        }
    }
}

// MARK: - Large

private struct AVIAWidgetLarge: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        AVIAGlassSurface {
            VStack(spacing: 10) {
                headerRow

                AVIAGlassProgressBar(value: snapshot.overallProgress, height: 7)

                // 2×2 bento — progress detail, contact, next step, package.
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    progressTile
                    contactTile
                    nextStepTile
                    packageTile
                }
                .frame(maxHeight: .infinity)
            }
            .padding(14)
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                AVIAEyebrow(text: "Your AVIA Build")
                Text(snapshot.homeDesign.isEmpty ? "AVIA Home" : snapshot.homeDesign)
                    .font(.aviaCorpMedium(20))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if !snapshot.estate.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 9))
                        Text("Lot \(snapshot.lotNumber) · \(snapshot.estate)")
                            .font(.aviaCorp(10))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(Int((snapshot.overallProgress * 100).rounded()))%")
                    .font(.aviaCorpUltralight(40))
                    .foregroundStyle(.white)
                Text("complete")
                    .font(.aviaCorp(9))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    // MARK: tiles

    private var progressTile: some View {
        AVIAGlassTile {
            VStack(alignment: .leading, spacing: 6) {
                AVIAEyebrow(text: "Current Stage", icon: "hammer")
                Spacer(minLength: 0)
                Text(snapshot.currentStageName.isEmpty ? "Awaiting start" : snapshot.currentStageName)
                    .font(.aviaCorpMedium(14))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text("\(snapshot.completedStages) of \(snapshot.totalStages) stages")
                    .font(.aviaCorp(10))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var contactTile: some View {
        AVIAGlassTile {
            VStack(alignment: .leading, spacing: 6) {
                AVIAEyebrow(text: "Your Contact", icon: "person.crop.circle")
                Spacer(minLength: 0)
                if let staff = snapshot.staff, !staff.name.isEmpty {
                    HStack(spacing: 8) {
                        ContactAvatar()
                        VStack(alignment: .leading, spacing: 1) {
                            Text(staff.name)
                                .font(.aviaCorpMedium(12))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(staff.roleLabel)
                                .font(.aviaCorp(9))
                                .foregroundStyle(.white.opacity(0.65))
                                .lineLimit(1)
                        }
                    }
                    HStack(spacing: 6) {
                        if !staff.phone.isEmpty {
                            ContactChip(icon: "phone.fill")
                        }
                        if !staff.email.isEmpty {
                            ContactChip(icon: "envelope.fill")
                        }
                    }
                } else {
                    Text("Your AVIA team is being assigned")
                        .font(.aviaCorp(11))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(3)
                }
            }
        }
    }

    private var nextStepTile: some View {
        AVIAGlassTile {
            VStack(alignment: .leading, spacing: 6) {
                AVIAEyebrow(text: "Next Step", icon: "arrow.forward")
                Spacer(minLength: 0)
                if snapshot.nextStepTitle.isEmpty {
                    Text("You're all caught up")
                        .font(.aviaCorpMedium(13))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                } else {
                    Text(snapshot.nextStepTitle)
                        .font(.aviaCorpMedium(13))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if !snapshot.nextStepDetail.isEmpty {
                        Text(snapshot.nextStepDetail)
                            .font(.aviaCorp(10))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    private var packageTile: some View {
        AVIAGlassTile {
            VStack(alignment: .leading, spacing: 6) {
                AVIAEyebrow(text: "Your Package", icon: "shippingbox")
                Spacer(minLength: 0)
                if let pkg = snapshot.package {
                    Text(pkg.title)
                        .font(.aviaCorpMedium(13))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if !pkg.location.isEmpty {
                        Text(pkg.location)
                            .font(.aviaCorp(10))
                            .foregroundStyle(.white.opacity(0.65))
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
                            .foregroundStyle(.white)
                    }
                } else {
                    Text("No package assigned yet")
                        .font(.aviaCorp(11))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Atoms

private struct ContactAvatar: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 30, height: 30)
            Circle()
                .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.6)
                .frame(width: 30, height: 30)
            Image(systemName: "person.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}

private struct ContactChip: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background {
                Capsule().fill(Color.white.opacity(0.15))
            }
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
            }
    }
}

private struct PackageBeat: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(value)
                .font(.aviaCorpMedium(10))
        }
        .foregroundStyle(.white.opacity(0.82))
    }
}

// MARK: - Widget configuration

struct AVIAHomesWidget: Widget {
    let kind: String = "AVIAHomesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BuildProvider()) { entry in
            AVIAHomesWidgetView(entry: entry)
        }
        .configurationDisplayName("AVIA Homes")
        .description("Your build progress, contact, next step and package — at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    AVIAHomesWidget()
} timeline: {
    BuildEntry(date: .now, snapshot: .previewBuildProgress)
    BuildEntry(date: .now, snapshot: .previewSpecs)
    BuildEntry(date: .now, snapshot: .previewPackage)
}

#Preview("Medium", as: .systemMedium) {
    AVIAHomesWidget()
} timeline: {
    BuildEntry(date: .now, snapshot: .previewBuildProgress)
}

#Preview("Large", as: .systemLarge) {
    AVIAHomesWidget()
} timeline: {
    BuildEntry(date: .now, snapshot: .previewBuildProgress)
}

// MARK: - Preview fixtures

private extension WidgetSnapshot {
    static let previewBuildProgress = WidgetSnapshot(
        kind: .buildProgress,
        userFirstName: "Lewis",
        homeDesign: "Alicante 241",
        estate: "Mermaid Beach",
        lotNumber: "12",
        currentStageName: "Frame & Roof",
        currentStageDescription: "Frame installation is underway on site",
        overallProgress: 0.42,
        stageProgress: 0.6,
        totalStages: 8,
        completedStages: 3,
        isAwaitingRegistration: false,
        specsRemaining: 0, specsTotal: 87,
        coloursRemaining: 0, coloursTotal: 24,
        nextStepTitle: "Frame inspection",
        nextStepDetail: "Independent certifier walk-through on Tue 19 May",
        staff: WidgetStaffContact(
            name: "Sarah Chen",
            roleLabel: "Build Manager",
            phone: "0400 123 456",
            email: "sarah@aviahomes.com.au"
        ),
        package: WidgetPackageSummary(
            title: "Alicante 241 · Premier",
            location: "Mermaid Beach, QLD",
            homeDesign: "Alicante 241",
            price: "$1,289,000",
            bedrooms: 4, bathrooms: 3, garages: 2,
            imageURL: nil,
            responseStatus: "Accepted"
        ),
        news: [],
        updatedAt: .now
    )

    static let previewSpecs = WidgetSnapshot(
        kind: .awaitingSpecs,
        userFirstName: "Lewis",
        homeDesign: "Alicante 241",
        estate: "Mermaid Beach",
        lotNumber: "12",
        currentStageName: "Selections",
        currentStageDescription: "",
        overallProgress: 0.18,
        stageProgress: 0,
        totalStages: 8,
        completedStages: 1,
        isAwaitingRegistration: false,
        specsRemaining: 14, specsTotal: 87,
        coloursRemaining: 0, coloursTotal: 24,
        nextStepTitle: "Confirm bathroom selections",
        nextStepDetail: "",
        staff: nil,
        package: nil,
        news: [],
        updatedAt: .now
    )

    static let previewPackage = WidgetSnapshot(
        kind: .packageAssigned,
        userFirstName: "Lewis",
        homeDesign: "Alicante 241",
        estate: "Mermaid Beach",
        lotNumber: "12",
        currentStageName: "",
        currentStageDescription: "",
        overallProgress: 0,
        stageProgress: 0,
        totalStages: 0,
        completedStages: 0,
        isAwaitingRegistration: false,
        specsRemaining: 0, specsTotal: 0,
        coloursRemaining: 0, coloursTotal: 0,
        nextStepTitle: "",
        nextStepDetail: "",
        staff: nil,
        package: WidgetPackageSummary(
            title: "Alicante 241 · Premier",
            location: "Mermaid Beach, QLD",
            homeDesign: "Alicante 241",
            price: "$1,289,000",
            bedrooms: 4, bathrooms: 3, garages: 2,
            imageURL: nil,
            responseStatus: "Accepted"
        ),
        news: [],
        updatedAt: .now
    )
}
