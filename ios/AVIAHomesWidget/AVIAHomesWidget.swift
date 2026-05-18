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

// MARK: - Helpers

private func overallProgressPercent(_ snapshot: WidgetSnapshot) -> Int {
    Int((snapshot.overallProgress * 100).rounded())
}

private func stageIcon(for kind: WidgetSnapshotKind) -> String {
    switch kind {
    case .buildProgress:   return "hammer"
    case .awaitingSpecs:   return "doc.text"
    case .awaitingColours: return "paintpalette"
    case .packageAssigned: return "shippingbox"
    case .noBuild:         return "house"
    }
}

private func journeyHeading(for kind: WidgetSnapshotKind) -> String {
    switch kind {
    case .buildProgress:   return "Your Journey"
    case .awaitingSpecs:   return "Selections"
    case .awaitingColours: return "Colours"
    case .packageAssigned: return "Your Package"
    case .noBuild:         return "Welcome Home"
    }
}

private func stageTitle(_ snapshot: WidgetSnapshot) -> String {
    if !snapshot.currentStageName.isEmpty { return snapshot.currentStageName }
    switch snapshot.kind {
    case .awaitingSpecs:   return "Selections pending"
    case .awaitingColours: return "Colours pending"
    case .packageAssigned: return snapshot.package?.title ?? "Your Package"
    case .noBuild:         return "Discover AVIA homes"
    case .buildProgress:   return "In progress"
    }
}

private func actionLabel(_ snapshot: WidgetSnapshot) -> String {
    switch snapshot.kind {
    case .buildProgress:   return "View Journey"
    case .awaitingSpecs:   return "Make Selections"
    case .awaitingColours: return "Choose Colours"
    case .packageAssigned: return "View Package"
    case .noBuild:         return "Explore Homes"
    }
}

// MARK: - Root view

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
            AVIAWidgetBrand.cardBackground
        }
    }
}

// MARK: - Small  ·  compact journey card

private struct AVIAWidgetSmall: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Mini header row — AVIA mark + step counter
            HStack(alignment: .center, spacing: 6) {
                AVIAWordmark(height: 11)
                Spacer()
                Text("Step \(min(snapshot.completedStages + 1, max(snapshot.totalStages, 1))) of \(max(snapshot.totalStages, 1))")
                    .font(.aviaCorp(9))
                    .foregroundStyle(AVIAWidgetBrand.textTertiary)
            }
            .padding(.bottom, 8)

            Divider().overlay(AVIAWidgetBrand.surfaceBorder)
                .padding(.bottom, 8)

            // Body — ring + journey label + stage title
            HStack(spacing: 10) {
                AVIAProgressRing(
                    progress: snapshot.overallProgress,
                    icon: stageIcon(for: snapshot.kind),
                    diameter: 40,
                    lineWidth: 3.5
                )
                VStack(alignment: .leading, spacing: 2) {
                    AVIAEyebrow(text: journeyHeading(for: snapshot.kind), size: 9)
                    Text(stageTitle(snapshot))
                        .font(.aviaCorpMedium(12))
                        .foregroundStyle(AVIAWidgetBrand.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }

            Spacer(minLength: 8)

            AVIAStageIndicator(
                total: max(snapshot.totalStages, 1),
                current: snapshot.completedStages,
                dotSize: 10,
                fillSize: 4
            )
            .padding(.bottom, 6)

            Text("\(overallProgressPercent(snapshot))% complete")
                .font(.aviaCorp(9))
                .foregroundStyle(AVIAWidgetBrand.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Medium  ·  journey card with header

private struct AVIAWidgetMedium: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Divider().overlay(AVIAWidgetBrand.surfaceBorder)
            journeyBody
            Divider().overlay(AVIAWidgetBrand.surfaceBorder)
            footerRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // Mirrors dashboard headerRow — wordmark left, completion chip right.
    private var headerRow: some View {
        HStack(alignment: .center) {
            AVIAWordmark(height: 14)
            Spacer()
            Text("\(overallProgressPercent(snapshot))% complete")
                .font(.aviaCorpMedium(10))
                .foregroundStyle(AVIAWidgetBrand.timelessBrown)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(AVIAWidgetBrand.timelessBrown.opacity(0.10))
                .clipShape(Capsule())
        }
        .padding(.vertical, 10)
    }

    // Mirrors BuildJourneyCard.headerSection — ring + journey + stage title.
    private var journeyBody: some View {
        HStack(alignment: .center, spacing: 12) {
            AVIAProgressRing(
                progress: snapshot.overallProgress,
                icon: stageIcon(for: snapshot.kind),
                diameter: 46,
                lineWidth: 4
            )
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    AVIAEyebrow(text: journeyHeading(for: snapshot.kind))
                    Spacer()
                    Text("Step \(min(snapshot.completedStages + 1, max(snapshot.totalStages, 1))) of \(max(snapshot.totalStages, 1))")
                        .font(.aviaCorp(9))
                        .foregroundStyle(AVIAWidgetBrand.textTertiary)
                }
                Text(stageTitle(snapshot))
                    .font(.aviaCorpMedium(15))
                    .foregroundStyle(AVIAWidgetBrand.textPrimary)
                    .lineLimit(1)
                if !snapshot.nextStepTitle.isEmpty {
                    Text(snapshot.nextStepTitle)
                        .font(.aviaCorp(10))
                        .foregroundStyle(AVIAWidgetBrand.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 12)
    }

    // Stage dots row.
    private var footerRow: some View {
        AVIAStageIndicator(
            total: max(snapshot.totalStages, 1),
            current: snapshot.completedStages,
            dotSize: 14,
            fillSize: 6
        )
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
    }
}

// MARK: - Large  ·  full dashboard mini

private struct AVIAWidgetLarge: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(spacing: 10) {
            dashboardHeader

            // Hero row — Build Progress gauge + Contact block (mirrors dashboard)
            HStack(spacing: 10) {
                buildProgressCard
                staffCard
            }
            .frame(maxHeight: .infinity)

            // Package card sits below, full width
            packageCard
                .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Build Progress card (semicircular gauge, mirrors dashboard)

    @ViewBuilder
    private var buildProgressCard: some View {
        AVIABentoCard(cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Build Progress")
                    .font(.aviaCorpMedium(11))
                    .foregroundStyle(AVIAWidgetBrand.textSecondary)
                Spacer(minLength: 0)
                AVIASemicircleGauge(progress: snapshot.overallProgress)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    GaugeLegendDot(color: AVIAWidgetBrand.timelessBrown, label: "Complete")
                    GaugeLegendDot(color: AVIAWidgetBrand.surfaceElevated, label: "Remaining")
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Dashboard header (mirror DashboardView.headerRow at small scale)

    private var dashboardHeader: some View {
        HStack(alignment: .center) {
            AVIAWordmark(height: 16)
            Spacer()
            if !snapshot.userFirstName.isEmpty {
                Text("Welcome, \(snapshot.userFirstName)")
                    .font(.aviaCorpMedium(12))
                    .foregroundStyle(AVIAWidgetBrand.timelessBrown)
            }
        }
    }

    // MARK: - Staff card (mirrors DashboardView.staffContactCard — photo + dark gradient)

    @ViewBuilder
    private var staffCard: some View {
        ZStack(alignment: .bottomLeading) {
            // Background: drew_photo for Drew Holden, else dark cream surface
            if let staff = snapshot.staff, staff.name.localizedCaseInsensitiveContains("Drew") {
                Image("drew_photo")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                AVIAWidgetBrand.surfaceElevated
                Image(systemName: "person.crop.circle.fill")
                    .font(.aviaCorpMedium(48))
                    .foregroundStyle(AVIAWidgetBrand.timelessBrown.opacity(0.25))
            }

            // Dark gradient overlay (matches in-app card)
            LinearGradient(
                stops: [
                    .init(color: Color.clear, location: 0.0),
                    .init(color: AVIAWidgetBrand.aviaBlack.opacity(0.35), location: 0.45),
                    .init(color: AVIAWidgetBrand.aviaBlack.opacity(0.8), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Text overlay bottom-left
            VStack(alignment: .leading, spacing: 3) {
                if let staff = snapshot.staff, !staff.name.isEmpty {
                    Text(staff.name)
                        .font(.aviaCorpMedium(13))
                        .foregroundStyle(AVIAWidgetBrand.aviaWhite)
                        .lineLimit(1)
                    Text(staff.roleLabel)
                        .font(.aviaCorp(9))
                        .foregroundStyle(AVIAWidgetBrand.aviaWhite.opacity(0.75))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        if !staff.phone.isEmpty {
                            StaffChip(icon: "phone.fill")
                        }
                        if !staff.email.isEmpty {
                            StaffChip(icon: "envelope.fill")
                        }
                    }
                    .padding(.top, 4)
                } else {
                    Text("Your AVIA Contact")
                        .font(.aviaCorpMedium(12))
                        .foregroundStyle(AVIAWidgetBrand.aviaWhite)
                    Text("Being assigned")
                        .font(.aviaCorp(9))
                        .foregroundStyle(AVIAWidgetBrand.aviaWhite.opacity(0.75))
                }
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    // MARK: - Package card (mirrors DashboardView.packageCard)

    @ViewBuilder
    private var packageCard: some View {
        AVIABentoCard(cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    AVIAEyebrow(text: "My Package", size: 9)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.aviaCorpMedium(9))
                        .foregroundStyle(AVIAWidgetBrand.textTertiary)
                }
                Spacer(minLength: 0)
                if let pkg = snapshot.package {
                    Text(pkg.title)
                        .font(.aviaCorpMedium(13))
                        .foregroundStyle(AVIAWidgetBrand.textPrimary)
                        .lineLimit(1)
                    if !pkg.location.isEmpty {
                        Text(pkg.location)
                            .font(.aviaCorp(9))
                            .foregroundStyle(AVIAWidgetBrand.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
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
                    Spacer(minLength: 0)
                    AVIABentoIcon(icon: "shippingbox", size: 32)
                    Text("No package yet")
                        .font(.aviaCorpMedium(12))
                        .foregroundStyle(AVIAWidgetBrand.textPrimary)
                    Text("Explore home & land")
                        .font(.aviaCorp(9))
                        .foregroundStyle(AVIAWidgetBrand.textSecondary)
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

// MARK: - Small atoms

private struct StaffChip: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.aviaCorpMedium(11))
            .foregroundStyle(AVIAWidgetBrand.aviaWhite)
            .frame(width: 28, height: 28)
            .background(.ultraThinMaterial, in: Circle())
            .overlay(
                Circle().stroke(AVIAWidgetBrand.aviaWhite.opacity(0.18), lineWidth: 0.5)
            )
    }
}

// MARK: - Semicircular gauge (mirrors dashboard Build Progress gauge)

private struct AVIASemicircleGauge: View {
    let progress: Double
    var lineWidth: CGFloat = 10

    private var clamped: Double { max(0, min(1, progress)) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let diameter = min(w, geo.size.height * 2)
            ZStack {
                // Track — full half-circle background
                Semicircle(trim: 1)
                    .stroke(
                        AVIAWidgetBrand.surfaceElevated,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                // Filled — proportional
                Semicircle(trim: clamped)
                    .stroke(
                        AVIAWidgetBrand.timelessBrown,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )

                // Centred percentage label sits just below the arc midpoint
                VStack(spacing: 0) {
                    Spacer()
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(Int((clamped * 100).rounded()))")
                            .font(.aviaCorpMedium(28))
                            .foregroundStyle(AVIAWidgetBrand.textPrimary)
                        Text("%")
                            .font(.aviaCorp(12))
                            .foregroundStyle(AVIAWidgetBrand.textSecondary)
                    }
                }
                .frame(width: diameter, height: diameter / 2)
            }
            .frame(width: diameter, height: diameter / 2)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: 70)
    }
}

private struct Semicircle: Shape {
    var trim: Double  // 0...1
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let radius = min(rect.width / 2, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let start = Angle.degrees(180)
        let end = Angle.degrees(180 + 180 * max(0, min(1, trim)))
        p.addArc(center: center, radius: radius - 5, startAngle: start, endAngle: end, clockwise: false)
        return p
    }
}

private struct GaugeLegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.aviaCorp(9))
                .foregroundStyle(AVIAWidgetBrand.textSecondary)
        }
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
        .description("Your build progress, your contact, and your next step — at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
            roleLabel: "Pre-Site Coordinator",
            phone: "+61 468 040 280",
            email: "drew@aviahomes.com.au"
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
