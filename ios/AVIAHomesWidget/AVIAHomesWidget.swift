import WidgetKit
import SwiftUI

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

// MARK: - Brand palette

private let aviaBlack = Color(red: 26/255, green: 26/255, blue: 26/255)
private let timelessBrown = Color(red: 55/255, green: 51/255, blue: 43/255)
private let aviaWhite = Color(red: 225/255, green: 221/255, blue: 220/255)
private let heritageBlue = Color(red: 142/255, green: 155/255, blue: 146/255)
private let warmSand = Color(red: 196/255, green: 178/255, blue: 156/255)

// MARK: - Frosted background

/// Beautiful aurora background that sits behind the glass.
/// Uses warm, brand-aligned colour blobs to give the frosted glass
/// something interesting to refract.
private struct AuroraBackground: View {
    var tint: Tint = .dark

    enum Tint { case dark, warm, sky }

    var body: some View {
        ZStack {
            base
            // Soft colour blobs — give the frosted glass something to read.
            Circle()
                .fill(blobA)
                .frame(width: 260, height: 260)
                .blur(radius: 60)
                .offset(x: -90, y: -110)
            Circle()
                .fill(blobB)
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(x: 120, y: 80)
            Circle()
                .fill(blobC)
                .frame(width: 180, height: 180)
                .blur(radius: 80)
                .offset(x: 40, y: 160)
        }
    }

    private var base: some View {
        LinearGradient(
            colors: baseColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var baseColors: [Color] {
        switch tint {
        case .dark: return [aviaBlack, timelessBrown, aviaBlack]
        case .warm: return [timelessBrown, warmSand.opacity(0.6), aviaBlack]
        case .sky:  return [heritageBlue.opacity(0.8), timelessBrown, aviaBlack]
        }
    }

    private var blobA: Color {
        switch tint {
        case .dark: return heritageBlue.opacity(0.55)
        case .warm: return warmSand.opacity(0.75)
        case .sky:  return aviaWhite.opacity(0.35)
        }
    }
    private var blobB: Color {
        switch tint {
        case .dark: return warmSand.opacity(0.45)
        case .warm: return heritageBlue.opacity(0.55)
        case .sky:  return heritageBlue.opacity(0.7)
        }
    }
    private var blobC: Color {
        switch tint {
        case .dark: return timelessBrown.opacity(0.7)
        case .warm: return aviaBlack.opacity(0.5)
        case .sky:  return warmSand.opacity(0.4)
        }
    }
}

/// Frosted glass card — translucent material with a subtle highlight stroke,
/// echoing iOS 26 liquid glass. Apply as a background of inner content.
private struct GlassPanel: View {
    var cornerRadius: CGFloat = 22

    var body: some View {
        ZStack {
            // Frosted base
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            // Warm tint so glass picks up the AVIA palette
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.06))
            // Specular top highlight
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .blendMode(.plusLighter)
            // Edge stroke
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.7
                )
        }
    }
}

private extension View {
    /// Apply a frosted glass surface as background.
    func glassSurface(cornerRadius: CGFloat = 18) -> some View {
        background(GlassPanel(cornerRadius: cornerRadius))
    }
}

/// Container background helper — image (if any) + aurora + faint vignette.
private struct FrostedWidgetBackground: View {
    let imageURL: String?
    var tint: AuroraBackground.Tint = .dark

    var body: some View {
        ZStack {
            AuroraBackground(tint: tint)
            if let urlString = imageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .allowsHitTesting(false)
                            .opacity(0.55)
                            .blur(radius: 14)
                    }
                }
            }
            // Bottom vignette so foreground text always reads
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

// MARK: - Root view

struct AVIAHomesWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: BuildProvider.Entry

    var body: some View {
        switch entry.snapshot.kind {
        case .noBuild:
            NoBuildWidgetView(snapshot: entry.snapshot, family: family)
        case .awaitingSpecs:
            SpecPromptWidgetView(snapshot: entry.snapshot, family: family)
        case .awaitingColours:
            ColourPromptWidgetView(snapshot: entry.snapshot, family: family)
        case .buildProgress:
            BuildProgressWidgetView(snapshot: entry.snapshot, family: family)
        case .packageAssigned:
            PackageWidgetView(snapshot: entry.snapshot, family: family)
        }
    }
}

// MARK: - Build progress

private struct BuildProgressWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily

    private var percentText: String {
        "\(Int((snapshot.overallProgress * 100).rounded()))%"
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemMedium: medium
            default: large
            }
        }
        .containerBackground(for: .widget) {
            FrostedWidgetBackground(imageURL: nil, tint: .sky)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 8) {
            EyebrowLabel(icon: "house.fill", text: "AVIA HOMES")
            Spacer(minLength: 0)
            Text(percentText)
                .font(.system(size: 38, weight: .light, design: .rounded))
                .foregroundStyle(.white)
            GlassProgressBar(value: snapshot.overallProgress)
            Text(snapshot.currentStageName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(2)
        }
        .padding(14)
        .glassSurface(cornerRadius: 22)
        .padding(2)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    EyebrowLabel(icon: nil, text: "YOUR BUILD")
                    Text(snapshot.homeDesign.isEmpty ? "AVIA Home" : snapshot.homeDesign)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer()
                Text(percentText)
                    .font(.system(size: 30, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
            }

            GlassProgressBar(value: snapshot.overallProgress)

            HStack(spacing: 8) {
                GlassChip(icon: "hammer.fill", text: snapshot.currentStageName)
                Spacer(minLength: 0)
            }

            if !snapshot.nextStepTitle.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                    Text(snapshot.nextStepTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
            } else {
                Text("\(snapshot.completedStages) of \(snapshot.totalStages) stages complete")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(14)
        .glassSurface(cornerRadius: 24)
        .padding(2)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    EyebrowLabel(icon: nil, text: "YOUR BUILD")
                    Text(snapshot.homeDesign.isEmpty ? "AVIA Home" : snapshot.homeDesign)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer()
                Text(percentText)
                    .font(.system(size: 34, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
            }

            GlassProgressBar(value: snapshot.overallProgress)

            HStack(spacing: 8) {
                GlassChip(icon: "hammer.fill", text: snapshot.currentStageName)
                Spacer()
                Text("\(snapshot.completedStages)/\(snapshot.totalStages)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            if !snapshot.nextStepTitle.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    EyebrowLabel(icon: "arrow.forward", text: "NEXT STEP")
                    Text(snapshot.nextStepTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if !snapshot.nextStepDetail.isEmpty {
                        Text(snapshot.nextStepDetail)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(2)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassSurface(cornerRadius: 14)
            }

            if let staff = snapshot.staff, !staff.name.isEmpty {
                StaffContactRow(staff: staff)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassSurface(cornerRadius: 14)
            }

            Spacer(minLength: 0)

            if !snapshot.estate.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption2)
                    Text("Lot \(snapshot.lotNumber) · \(snapshot.estate)")
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                }
                .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(16)
        .glassSurface(cornerRadius: 26)
        .padding(2)
    }
}

// MARK: - Shared glass components

private struct EyebrowLabel: View {
    let icon: String?
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            Text(text)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

private struct GlassProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.15))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.white, aviaWhite.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(6, geo.size.width * max(0, min(1, value))))
                    .shadow(color: Color.white.opacity(0.4), radius: 4, y: 0)
            }
        }
        .frame(height: 6)
    }
}

private struct GlassChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.6)
        )
    }
}

private struct StaffContactRow: View {
    let staff: WidgetStaffContact

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.18))
                Circle()
                    .strokeBorder(.white.opacity(0.3), lineWidth: 0.6)
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(staff.name.isEmpty ? "Your AVIA team" : staff.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(staff.roleLabel)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            Spacer()
            HStack(spacing: 6) {
                if !staff.phone.isEmpty {
                    Image(systemName: "phone.fill")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }
                if !staff.email.isEmpty {
                    Image(systemName: "envelope.fill")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
    }
}

// MARK: - Spec / colour prompts

private struct SpecPromptWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily

    var body: some View {
        PromptCard(
            title: "Action needed",
            heading: "Confirm your spec selections",
            detail: snapshot.specsTotal == 0
                ? "Your AVIA team is preparing your specifications."
                : "\(snapshot.specsRemaining) of \(snapshot.specsTotal) items still need your review.",
            icon: "doc.text.fill",
            family: family,
            progress: snapshot.specsTotal == 0 ? 0 : Double(snapshot.specsTotal - snapshot.specsRemaining) / Double(snapshot.specsTotal),
            staff: snapshot.staff
        )
    }
}

private struct ColourPromptWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily

    var body: some View {
        PromptCard(
            title: "Action needed",
            heading: "Make your colour selections",
            detail: snapshot.coloursTotal == 0
                ? "Your colour palette is being unlocked. Check back soon."
                : "\(snapshot.coloursRemaining) of \(snapshot.coloursTotal) colours still to choose.",
            icon: "paintpalette.fill",
            family: family,
            progress: snapshot.coloursTotal == 0 ? 0 : Double(snapshot.coloursTotal - snapshot.coloursRemaining) / Double(snapshot.coloursTotal),
            staff: snapshot.staff
        )
    }
}

private struct PromptCard: View {
    let title: String
    let heading: String
    let detail: String
    let icon: String
    let family: WidgetFamily
    let progress: Double
    let staff: WidgetStaffContact?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.75))
            }

            Text(heading)
                .font(family == .systemSmall ? .subheadline.weight(.bold) : .title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(family == .systemSmall ? 3 : 2)

            if family != .systemSmall {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(3)
            }

            GlassProgressBar(value: max(0, min(1, progress)))

            if family == .systemLarge, let staff, !staff.name.isEmpty {
                StaffContactRow(staff: staff)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassSurface(cornerRadius: 14)
            }

            Spacer(minLength: 0)

            HStack {
                Text(family == .systemSmall ? detail : "Tap to open")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(14)
        .glassSurface(cornerRadius: 24)
        .padding(2)
        .containerBackground(for: .widget) {
            FrostedWidgetBackground(imageURL: nil, tint: .warm)
        }
    }
}

// MARK: - Package widget

private struct PackageWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemMedium: medium
            default: large
            }
        }
        .containerBackground(for: .widget) {
            FrostedWidgetBackground(imageURL: snapshot.package?.imageURL, tint: .dark)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowLabel(icon: "shippingbox.fill", text: "YOUR PACKAGE")
            Spacer(minLength: 0)
            Text(snapshot.package?.title ?? "House & Land Package")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(snapshot.package?.location ?? "")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
            if let pkg = snapshot.package {
                HStack(spacing: 6) {
                    PackageStat(icon: "bed.double.fill", value: "\(pkg.bedrooms)")
                    PackageStat(icon: "shower.fill", value: "\(pkg.bathrooms)")
                    PackageStat(icon: "car.fill", value: "\(pkg.garages)")
                }
            }
            if let price = snapshot.package?.price, !price.isEmpty {
                Text(price)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(14)
        .glassSurface(cornerRadius: 22)
        .padding(2)
    }

    private var medium: some View {
        HStack(spacing: 10) {
            if let urlString = snapshot.package?.imageURL, let url = URL(string: urlString) {
                Color.black.opacity(0.2)
                    .frame(width: 108)
                    .overlay {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(.white.opacity(0.25), lineWidth: 0.6)
                    )
                    .clipShape(.rect(cornerRadius: 14))
            }
            VStack(alignment: .leading, spacing: 4) {
                EyebrowLabel(icon: nil, text: "YOUR PACKAGE")
                Text(snapshot.package?.title ?? "House & Land")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(snapshot.package?.location ?? "")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                if let pkg = snapshot.package {
                    HStack(spacing: 6) {
                        PackageStat(icon: "bed.double.fill", value: "\(pkg.bedrooms)")
                        PackageStat(icon: "shower.fill", value: "\(pkg.bathrooms)")
                        PackageStat(icon: "car.fill", value: "\(pkg.garages)")
                    }
                }
                Spacer(minLength: 0)
                if let price = snapshot.package?.price, !price.isEmpty {
                    Text(price)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .glassSurface(cornerRadius: 24)
        .padding(2)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                EyebrowLabel(icon: nil, text: "YOUR PACKAGE")
                Spacer()
                if let status = snapshot.package?.responseStatus, !status.isEmpty {
                    Text(status.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.0)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: .capsule)
                        .overlay(Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.6))
                }
            }
            if let urlString = snapshot.package?.imageURL, let url = URL(string: urlString) {
                Color.black.opacity(0.2)
                    .frame(height: 120)
                    .overlay {
                        AsyncImage(url: url) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(.white.opacity(0.25), lineWidth: 0.6)
                    )
                    .clipShape(.rect(cornerRadius: 16))
            }
            Text(snapshot.package?.title ?? "House & Land Package")
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(snapshot.package?.location ?? "")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
            if let pkg = snapshot.package {
                HStack(spacing: 8) {
                    PackageStat(icon: "bed.double.fill", value: "\(pkg.bedrooms)")
                    PackageStat(icon: "shower.fill", value: "\(pkg.bathrooms)")
                    PackageStat(icon: "car.fill", value: "\(pkg.garages)")
                    Spacer()
                    if !pkg.price.isEmpty {
                        Text(pkg.price)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Text("Tap to view package")
                    .font(.caption.weight(.semibold))
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.white)
        }
        .padding(14)
        .glassSurface(cornerRadius: 26)
        .padding(2)
    }
}

private struct PackageStat: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
            Text(value)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(.white.opacity(0.12))
        )
        .overlay(
            Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5)
        )
    }
}

// MARK: - No build / news

private struct NoBuildWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily

    private var heroImageURL: String? {
        snapshot.news.first?.imageURL
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall: small
            case .systemMedium: medium
            default: large
            }
        }
        .containerBackground(for: .widget) {
            FrostedWidgetBackground(imageURL: heroImageURL, tint: .warm)
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            EyebrowLabel(icon: "newspaper.fill", text: "LATEST NEWS")
            Spacer(minLength: 0)
            if let first = snapshot.news.first {
                Text(first.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(4)
            } else {
                Text("Discover AVIA Homes")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
            HStack {
                Text("View more")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(14)
        .glassSurface(cornerRadius: 22)
        .padding(2)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                EyebrowLabel(icon: "newspaper.fill", text: "LATEST FROM AVIA")
                if let first = snapshot.news.first {
                    Text(first.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(3)
                    Text(first.excerpt)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                } else {
                    Text("Discover home designs, packages & news")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Text("View more in app")
                        .font(.caption.weight(.semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .glassSurface(cornerRadius: 24)
        .padding(2)
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                EyebrowLabel(icon: "newspaper.fill", text: "LATEST FROM AVIA")
                Spacer()
            }

            if snapshot.news.isEmpty {
                Spacer(minLength: 0)
                Text("Discover home designs, packages and the latest from AVIA Homes.")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            } else {
                ForEach(Array(snapshot.news.prefix(3).enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        if let urlString = item.imageURL, let url = URL(string: urlString) {
                            Color.black.opacity(0.2)
                                .frame(width: 44, height: 44)
                                .overlay {
                                    AsyncImage(url: url) { phase in
                                        if let image = phase.image {
                                            image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                                        }
                                    }
                                }
                                .clipShape(.rect(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(.white.opacity(0.25), lineWidth: 0.6)
                                )
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                            if !item.excerpt.isEmpty {
                                Text(item.excerpt)
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.75))
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    if index < min(snapshot.news.count, 3) - 1 {
                        Divider().background(.white.opacity(0.15))
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 4) {
                Text("View more in app")
                    .font(.caption.weight(.semibold))
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.white)
        }
        .padding(14)
        .glassSurface(cornerRadius: 26)
        .padding(2)
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
        .description("See your build progress, outstanding selections, your assigned package, or the latest from AVIA Homes.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
