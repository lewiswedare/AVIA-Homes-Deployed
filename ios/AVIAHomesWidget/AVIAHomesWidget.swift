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
                }

                if family == .systemLarge {
                    Divider().background(.white.opacity(0.15))
                    Text(snapshot.currentStageDescription.isEmpty ? "Your home is progressing through this stage. Tap for full timeline." : snapshot.currentStageDescription)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(4)
                    Spacer(minLength: 0)
                    HStack {
                        StatPill(icon: "checkmark.seal.fill", label: "\(snapshot.completedStages)/\(snapshot.totalStages) stages")
                        Spacer()
                        if !snapshot.estate.isEmpty {
                            StatPill(icon: "mappin.and.ellipse", label: "Lot \(snapshot.lotNumber) · \(snapshot.estate)")
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Text("\(snapshot.completedStages) of \(snapshot.totalStages) stages complete")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .containerBackground(for: .widget) {
                LinearGradient(colors: [aviaBrown, aviaBrownDark], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
}

private struct StatPill: View {
    let icon: String
    let label: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(label).font(.caption2.weight(.medium)).lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.white.opacity(0.12), in: .capsule)
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
            progress: snapshot.specsTotal == 0 ? 0 : Double(snapshot.specsTotal - snapshot.specsRemaining) / Double(snapshot.specsTotal)
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
            progress: snapshot.coloursTotal == 0 ? 0 : Double(snapshot.coloursTotal - snapshot.coloursRemaining) / Double(snapshot.coloursTotal)
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

            Spacer(minLength: 0)

            ProgressView(value: max(0, min(1, progress)))
                .progressViewStyle(.linear)
                .tint(aviaBrown)

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
        .description("See your build progress, outstanding selections, or the latest from AVIA Homes.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
