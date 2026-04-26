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

private let aviaBrown = Color(red: 0.36, green: 0.27, blue: 0.20)
private let aviaBrownDark = Color(red: 0.22, green: 0.16, blue: 0.12)
private let aviaGold = Color(red: 0.78, green: 0.62, blue: 0.36)
private let aviaCream = Color(red: 0.96, green: 0.94, blue: 0.90)

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
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "house.fill")
                        .font(.caption)
                        .foregroundStyle(aviaGold)
                    Text("AVIA HOMES")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer(minLength: 0)
                Text(percentText)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)
                ProgressView(value: snapshot.overallProgress)
                    .progressViewStyle(.linear)
                    .tint(aviaGold)
                Text(snapshot.currentStageName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
            }
            .containerBackground(for: .widget) {
                LinearGradient(colors: [aviaBrown, aviaBrownDark], startPoint: .top, endPoint: .bottom)
            }
        case .systemMedium:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("YOUR BUILD")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(snapshot.homeDesign.isEmpty ? "AVIA Home" : snapshot.homeDesign)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(percentText)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(aviaGold)
                }

                ProgressView(value: snapshot.overallProgress)
                    .progressViewStyle(.linear)
                    .tint(aviaGold)

                HStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .font(.caption)
                        .foregroundStyle(aviaGold)
                    Text(snapshot.currentStageName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                if !snapshot.nextStepTitle.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.forward.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
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
            .containerBackground(for: .widget) {
                LinearGradient(colors: [aviaBrown, aviaBrownDark], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("YOUR BUILD")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.4)
                            .foregroundStyle(.white.opacity(0.7))
                        Text(snapshot.homeDesign.isEmpty ? "AVIA Home" : snapshot.homeDesign)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(percentText)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(aviaGold)
                }

                ProgressView(value: snapshot.overallProgress)
                    .progressViewStyle(.linear)
                    .tint(aviaGold)

                HStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .font(.caption)
                        .foregroundStyle(aviaGold)
                    Text(snapshot.currentStageName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Text("\(snapshot.completedStages)/\(snapshot.totalStages)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }

                if !snapshot.nextStepTitle.isEmpty {
                    Divider().background(.white.opacity(0.15))
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.forward.circle.fill")
                                .font(.caption)
                                .foregroundStyle(aviaGold)
                            Text("NEXT STEP")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(1.2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
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
                }

                if let staff = snapshot.staff, !staff.name.isEmpty {
                    Divider().background(.white.opacity(0.15))
                    StaffContactRow(staff: staff)
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
            .containerBackground(for: .widget) {
                LinearGradient(colors: [aviaBrown, aviaBrownDark], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
}

private struct StaffContactRow: View {
    let staff: WidgetStaffContact

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(aviaGold.opacity(0.25))
                    .frame(width: 32, height: 32)
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundStyle(aviaGold)
            }
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
            if !staff.phone.isEmpty {
                Image(systemName: "phone.fill")
                    .font(.caption2)
                    .foregroundStyle(aviaGold)
            }
            if !staff.email.isEmpty {
                Image(systemName: "envelope.fill")
                    .font(.caption2)
                    .foregroundStyle(aviaGold)
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(aviaBrown)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(aviaBrown.opacity(0.7))
            }

            Text(heading)
                .font(family == .systemSmall ? .subheadline.weight(.bold) : .title3.weight(.bold))
                .foregroundStyle(aviaBrownDark)
                .lineLimit(family == .systemSmall ? 3 : 2)

            if family != .systemSmall {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(aviaBrownDark.opacity(0.75))
                    .lineLimit(3)
            }

            ProgressView(value: max(0, min(1, progress)))
                .progressViewStyle(.linear)
                .tint(aviaBrown)

            if family == .systemLarge, let staff, !staff.name.isEmpty {
                Divider()
                LightStaffContactRow(staff: staff)
            }

            Spacer(minLength: 0)

            HStack {
                Text(family == .systemSmall ? detail : "Tap to open")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(aviaBrown)
                    .lineLimit(2)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(aviaBrown)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: [aviaCream, .white], startPoint: .top, endPoint: .bottom)
        }
    }
}

private struct LightStaffContactRow: View {
    let staff: WidgetStaffContact

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(aviaBrown.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundStyle(aviaBrown)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(staff.name.isEmpty ? "Your AVIA team" : staff.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(aviaBrownDark)
                    .lineLimit(1)
                Text(staff.roleLabel)
                    .font(.caption2)
                    .foregroundStyle(aviaBrownDark.opacity(0.7))
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}

// MARK: - Package widget

private struct PackageWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "shippingbox.fill")
                        .font(.caption)
                        .foregroundStyle(aviaGold)
                    Text("YOUR PACKAGE")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer(minLength: 0)
                Text(snapshot.package?.title ?? "House & Land Package")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(snapshot.package?.location ?? "")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let price = snapshot.package?.price, !price.isEmpty {
                    Text(price)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(aviaGold)
                }
            }
            .containerBackground(for: .widget) {
                LinearGradient(colors: [aviaBrown, aviaBrownDark], startPoint: .top, endPoint: .bottom)
            }
        case .systemMedium:
            HStack(spacing: 12) {
                if let urlString = snapshot.package?.imageURL, let url = URL(string: urlString) {
                    Color.black.opacity(0.2)
                        .frame(width: 110)
                        .overlay {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                                }
                            }
                        }
                        .clipShape(.rect(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR PACKAGE")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.7))
                    Text(snapshot.package?.title ?? "House & Land")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(snapshot.package?.location ?? "")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                    if let pkg = snapshot.package {
                        HStack(spacing: 8) {
                            PackageStat(icon: "bed.double.fill", value: "\(pkg.bedrooms)")
                            PackageStat(icon: "shower.fill", value: "\(pkg.bathrooms)")
                            PackageStat(icon: "car.fill", value: "\(pkg.garages)")
                        }
                    }
                    Spacer(minLength: 0)
                    if let price = snapshot.package?.price, !price.isEmpty {
                        Text(price)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(aviaGold)
                    }
                }
                Spacer(minLength: 0)
            }
            .containerBackground(for: .widget) {
                LinearGradient(colors: [aviaBrown, aviaBrownDark], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("YOUR PACKAGE")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    if let status = snapshot.package?.responseStatus, !status.isEmpty {
                        Text(status.uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1.0)
                            .foregroundStyle(aviaGold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(aviaGold.opacity(0.18), in: .capsule)
                    }
                }
                if let urlString = snapshot.package?.imageURL, let url = URL(string: urlString) {
                    Color.black.opacity(0.2)
                        .frame(height: 110)
                        .overlay {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill).allowsHitTesting(false)
                                }
                            }
                        }
                        .clipShape(.rect(cornerRadius: 10))
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
                    HStack(spacing: 12) {
                        PackageStat(icon: "bed.double.fill", value: "\(pkg.bedrooms)")
                        PackageStat(icon: "shower.fill", value: "\(pkg.bathrooms)")
                        PackageStat(icon: "car.fill", value: "\(pkg.garages)")
                        Spacer()
                        if !pkg.price.isEmpty {
                            Text(pkg.price)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(aviaGold)
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
                .foregroundStyle(aviaGold)
            }
            .containerBackground(for: .widget) {
                LinearGradient(colors: [aviaBrown, aviaBrownDark], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
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
        .foregroundStyle(.white.opacity(0.85))
    }
}

// MARK: - No build / news

private struct NoBuildWidgetView: View {
    let snapshot: WidgetSnapshot
    let family: WidgetFamily

    var body: some View {
        switch family {
        case .systemSmall:
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "newspaper.fill")
                        .font(.caption)
                        .foregroundStyle(aviaGold)
                    Text("LATEST NEWS")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.7))
                }
                if let first = snapshot.news.first {
                    Spacer(minLength: 0)
                    Text(first.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(4)
                } else {
                    Spacer(minLength: 0)
                    Text("Discover AVIA Homes")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 0)
                HStack {
                    Text("View more")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(aviaGold)
                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(aviaGold)
                }
            }
            .containerBackground(for: .widget) {
                LinearGradient(colors: [aviaBrown, aviaBrownDark], startPoint: .top, endPoint: .bottom)
            }
        case .systemMedium:
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LATEST FROM AVIA")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.7))
                    if let first = snapshot.news.first {
                        Text(first.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(3)
                        Text(first.excerpt)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
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
                    .foregroundStyle(aviaGold)
                }
                Spacer(minLength: 0)
            }
            .containerBackground(for: .widget) {
                LinearGradient(colors: [aviaBrown, aviaBrownDark], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        default:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("LATEST FROM AVIA")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Image(systemName: "newspaper.fill")
                        .font(.caption)
                        .foregroundStyle(aviaGold)
                }

                if snapshot.news.isEmpty {
                    Spacer(minLength: 0)
                    Text("Discover home designs, packages and the latest from AVIA Homes.")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer(minLength: 0)
                } else {
                    ForEach(Array(snapshot.news.prefix(3).enumerated()), id: \.element.id) { index, item in
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
                .foregroundStyle(aviaGold)
            }
            .containerBackground(for: .widget) {
                LinearGradient(colors: [aviaBrown, aviaBrownDark], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
}

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
