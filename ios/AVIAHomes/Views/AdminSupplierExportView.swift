import SwiftUI
import UIKit

// Supplier-grouped export of every variant with SKUs, room assignments, and
// per-(room × range) cost + inclusion. Generates a PDF and a CSV for sharing.

struct AdminSupplierExportView: View {
    @State private var isLoading = true
    @State private var groups: [SupplierExportGroup] = []
    @State private var generatedFile: URL?
    @State private var showShareSheet = false
    @State private var format: ExportFormat = .pdf
    @State private var query: String = ""

    enum ExportFormat: String, CaseIterable, Identifiable {
        case pdf, csv
        var id: String { rawValue }
        var label: String { rawValue.uppercased() }
    }

    private var filteredGroups: [SupplierExportGroup] {
        if query.isEmpty { return groups }
        return groups.compactMap { group in
            let entries = group.entries.filter {
                $0.itemName.localizedStandardContains(query) ||
                $0.variantName.localizedStandardContains(query) ||
                ($0.variantSKU ?? "").localizedStandardContains(query) ||
                ($0.itemSKU ?? "").localizedStandardContains(query)
            }
            guard !entries.isEmpty else { return nil }
            return SupplierExportGroup(supplier: group.supplier, entries: entries)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                summaryCard

                Picker("Format", selection: $format) {
                    ForEach(ExportFormat.allCases) { f in
                        Text(f.label).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                Button { Task { await generate() } } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text("Generate \(format.label) Export")
                            .font(.neueSubheadlineMedium)
                    }
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 11))
                    .padding(.horizontal, 16)
                }
                .disabled(isLoading || groups.isEmpty)

                if isLoading {
                    ProgressView().tint(AVIATheme.timelessBrown).padding(.vertical, 60)
                } else if groups.isEmpty {
                    AdminEmptyState(
                        icon: "shippingbox",
                        title: "No Variants",
                        subtitle: "Add items and variants first, then assign them to rooms."
                    )
                } else {
                    ForEach(filteredGroups) { group in
                        supplierCard(group)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.bottom, 40)
        }
        .background(AVIATheme.background)
        .navigationTitle("Supplier Export")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, prompt: "Search items, variants, SKUs...")
        .sheet(isPresented: $showShareSheet) {
            if let url = generatedFile {
                ShareSheetView(items: [url])
            }
        }
        .task { await load() }
    }

    private var summaryCard: some View {
        BentoCard(cornerRadius: 11) {
            HStack(spacing: 14) {
                Image(systemName: "square.and.arrow.up.on.square.fill")
                    .font(.neueCorpMedium(16))
                    .foregroundStyle(AVIATheme.success)
                    .frame(width: 44, height: 44)
                    .background(AVIATheme.success.opacity(0.12))
                    .clipShape(.rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(groups.count) Suppliers · \(groups.flatMap(\.entries).count) Variants")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Includes SKUs, room assignments, inclusion status, and per-range cost.")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                Spacer()
            }
            .padding(14)
        }
        .padding(.horizontal, 16)
    }

    private func supplierCard(_ group: SupplierExportGroup) -> some View {
        BentoCard(cornerRadius: 11) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(group.supplier.isEmpty ? "Unassigned supplier" : group.supplier)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    Text("\(group.entries.count) variant\(group.entries.count == 1 ? "" : "s")")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }

                ForEach(group.entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(entry.itemName)
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text("·")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                            Text(entry.variantName)
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                            Spacer()
                            if let sku = entry.variantSKU, !sku.isEmpty {
                                Text(sku)
                                    .font(.neueCaption2Medium)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AVIATheme.surfaceElevated)
                                    .clipShape(Capsule())
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                        }
                        if !entry.assignments.isEmpty {
                            FlowLayout(spacing: 4) {
                                ForEach(entry.assignments) { a in
                                    Text("\(a.roomName) · \(a.rangeName) · \(a.inclusion == .upgrade ? "+$\(Int(a.cost))" : "Incl")")
                                        .font(.neueCaption2)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background((a.inclusion == .upgrade ? AVIATheme.warning : AVIATheme.success).opacity(0.12))
                                        .foregroundStyle(a.inclusion == .upgrade ? AVIATheme.warning : AVIATheme.success)
                                        .clipShape(Capsule())
                                }
                            }
                        } else {
                            Text("No room assignments")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                    }
                    .padding(8)
                    .background(AVIATheme.surfaceElevated.opacity(0.4))
                    .clipShape(.rect(cornerRadius: 6))
                }
            }
            .padding(14)
        }
        .padding(.horizontal, 16)
    }

    private func load() async {
        isLoading = true
        let catalog = CatalogDataManager.shared
        if !catalog.isLoaded { await catalog.loadAll() }
        let flatItems = await SupabaseService.shared.fetchSpecItemsFlat()
        let rooms = catalog.allSpecCategories
        let roomName: [String: String] = Dictionary(uniqueKeysWithValues: rooms.map { ($0.id, $0.name) })
        let rangeName: [String: String] = ["volos": "Volos", "messina": "Messina", "portobello": "Portobello"]

        var bySupplier: [String: [SupplierExportEntry]] = [:]
        for item in flatItems {
            let productIds = catalog.productsBySpecItem[item.id] ?? []
            for pid in productIds {
                let variants = catalog.coloursByProduct[pid] ?? []
                for variant in variants {
                    let assignments: [SupplierExportAssignment] = catalog.variantRoomAssignments.values
                        .filter { $0.variant_id == variant.id }
                        .sorted { lhs, rhs in
                            if lhs.room_id != rhs.room_id { return lhs.room_id < rhs.room_id }
                            return lhs.range_id < rhs.range_id
                        }
                        .map { a in
                            SupplierExportAssignment(
                                roomId: a.room_id,
                                roomName: roomName[a.room_id] ?? a.room_id,
                                rangeId: a.range_id,
                                rangeName: rangeName[a.range_id] ?? a.range_id.capitalized,
                                inclusion: a.inclusionValue,
                                cost: a.cost,
                                imageURL: a.image_url
                            )
                        }
                    let entry = SupplierExportEntry(
                        itemId: item.id,
                        itemName: item.name,
                        itemSKU: item.sku,
                        variantId: variant.id,
                        variantName: variant.name,
                        variantSKU: variant.sku,
                        dimensions: item.dimensions,
                        description: item.description,
                        assignments: assignments
                    )
                    let key = (item.supplier ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    bySupplier[key, default: []].append(entry)
                }
            }
        }

        groups = bySupplier
            .map { SupplierExportGroup(supplier: $0.key, entries: $0.value.sorted { $0.itemName < $1.itemName }) }
            .sorted { lhs, rhs in
                if lhs.supplier.isEmpty != rhs.supplier.isEmpty { return !lhs.supplier.isEmpty }
                return lhs.supplier < rhs.supplier
            }
        isLoading = false
    }

    private func generate() async {
        guard !groups.isEmpty else { return }
        switch format {
        case .pdf:
            generatedFile = SupplierExportRenderer.makePDF(groups: groups)
        case .csv:
            generatedFile = SupplierExportRenderer.makeCSV(groups: groups)
        }
        if generatedFile != nil { showShareSheet = true }
    }
}

// MARK: - Models

struct SupplierExportGroup: Identifiable {
    var id: String { supplier.isEmpty ? "_unassigned" : supplier }
    let supplier: String
    let entries: [SupplierExportEntry]
}

struct SupplierExportEntry: Identifiable {
    var id: String { variantId }
    let itemId: String
    let itemName: String
    let itemSKU: String?
    let variantId: String
    let variantName: String
    let variantSKU: String?
    let dimensions: String?
    let description: String?
    let assignments: [SupplierExportAssignment]
}

struct SupplierExportAssignment: Identifiable {
    var id: String { "\(roomId)|\(rangeId)" }
    let roomId: String
    let roomName: String
    let rangeId: String
    let rangeName: String
    let inclusion: VariantInclusion
    let cost: Double
    let imageURL: String?
}

// MARK: - Renderer

enum SupplierExportRenderer {
    static func makePDF(groups: [SupplierExportGroup]) -> URL {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 40
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "AVIA_SupplierExport_\(Int(Date.now.timeIntervalSince1970)).pdf"
        )

        try? renderer.writePDF(to: url) { ctx in
            var y: CGFloat = 0
            func newPage() { ctx.beginPage(); y = margin }
            func ensure(_ h: CGFloat) { if y + h > pageHeight - margin { newPage() } }

            let titleFont = UIFont.boldSystemFont(ofSize: 18)
            let supplierFont = UIFont.boldSystemFont(ofSize: 13)
            let bodyFont = UIFont.systemFont(ofSize: 9.5)
            let smallFont = UIFont.systemFont(ofSize: 8)
            let dark = UIColor(white: 0.1, alpha: 1)
            let gray = UIColor(white: 0.4, alpha: 1)
            let light = UIColor(white: 0.7, alpha: 1)

            newPage()
            "AVIA Homes — Supplier Export".draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: titleFont, .foregroundColor: dark
            ])
            y += 26
            "Generated \(Date.now.formatted(date: .long, time: .shortened))".draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: smallFont, .foregroundColor: gray
            ])
            y += 20

            for group in groups {
                ensure(40)
                let supplierLabel = group.supplier.isEmpty ? "Unassigned Supplier" : group.supplier
                supplierLabel.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                    .font: supplierFont, .foregroundColor: dark
                ])
                y += 18
                let line = UIBezierPath()
                line.move(to: CGPoint(x: margin, y: y))
                line.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                light.setStroke(); line.lineWidth = 0.5; line.stroke()
                y += 8

                for entry in group.entries {
                    ensure(40)
                    let header = "\(entry.itemName) — \(entry.variantName)"
                    header.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                        .font: UIFont.boldSystemFont(ofSize: 10), .foregroundColor: dark
                    ])
                    let skuLabel: String = {
                        var bits: [String] = []
                        if let s = entry.itemSKU, !s.isEmpty { bits.append("Item SKU: \(s)") }
                        if let s = entry.variantSKU, !s.isEmpty { bits.append("Variant SKU: \(s)") }
                        return bits.joined(separator: " · ")
                    }()
                    if !skuLabel.isEmpty {
                        skuLabel.draw(at: CGPoint(x: margin, y: y + 12), withAttributes: [
                            .font: smallFont, .foregroundColor: gray
                        ])
                        y += 12
                    }
                    y += 14

                    if entry.assignments.isEmpty {
                        "No room assignments".draw(at: CGPoint(x: margin + 8, y: y), withAttributes: [
                            .font: smallFont, .foregroundColor: light
                        ])
                        y += 12
                    } else {
                        for a in entry.assignments {
                            ensure(12)
                            let costStr = a.inclusion == .upgrade ? String(format: "+$%.2f", a.cost) : "Included"
                            let line = "• \(a.roomName) · \(a.rangeName) · \(costStr)"
                            line.draw(at: CGPoint(x: margin + 8, y: y), withAttributes: [
                                .font: bodyFont, .foregroundColor: dark
                            ])
                            y += 11
                        }
                    }
                    if let dims = entry.dimensions, !dims.isEmpty {
                        ensure(12)
                        "Dimensions: \(dims)".draw(at: CGPoint(x: margin + 8, y: y), withAttributes: [
                            .font: smallFont, .foregroundColor: gray
                        ])
                        y += 11
                    }
                    if let desc = entry.description, !desc.isEmpty {
                        ensure(12)
                        let rect = CGRect(x: margin + 8, y: y, width: pageWidth - margin * 2 - 8, height: 22)
                        NSAttributedString(string: desc, attributes: [
                            .font: smallFont, .foregroundColor: gray
                        ]).draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
                        y += 22
                    }
                    y += 4
                }
                y += 8
            }
        }
        return url
    }

    static func makeCSV(groups: [SupplierExportGroup]) -> URL {
        var rows: [String] = [
            "Supplier,Item,Item SKU,Variant,Variant SKU,Dimensions,Room,Range,Inclusion,Cost"
        ]
        for group in groups {
            let supplier = csv(group.supplier)
            for entry in group.entries {
                let item = csv(entry.itemName)
                let itemSku = csv(entry.itemSKU ?? "")
                let variant = csv(entry.variantName)
                let variantSku = csv(entry.variantSKU ?? "")
                let dims = csv(entry.dimensions ?? "")
                if entry.assignments.isEmpty {
                    rows.append("\(supplier),\(item),\(itemSku),\(variant),\(variantSku),\(dims),,,,")
                } else {
                    for a in entry.assignments {
                        rows.append("\(supplier),\(item),\(itemSku),\(variant),\(variantSku),\(dims),\(csv(a.roomName)),\(csv(a.rangeName)),\(a.inclusion.rawValue),\(String(format: "%.2f", a.cost))")
                    }
                }
            }
        }
        let content = rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "AVIA_SupplierExport_\(Int(Date.now.timeIntervalSince1970)).csv"
        )
        try? content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func csv(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n")
        if needsQuoting {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}

// Simple flowing-tags layout for the assignment chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
