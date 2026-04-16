import UIKit

enum AdminPDFExporter {
    static func generateCombinedPDF(
        clientName: String,
        specTier: String,
        groupedSelections: [(category: String, categoryId: String, items: [BuildSpecSelection])],
        colourSelections: [BuildColourSelection],
        catalog: CatalogDataManager
    ) -> URL {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 50
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("AVIA_Selections_\(Date.now.timeIntervalSince1970).pdf")

        try? renderer.writePDF(to: url) { context in
            var y: CGFloat = 0

            func newPage() {
                context.beginPage()
                y = margin
            }

            func check(_ needed: CGFloat) {
                if y + needed > pageHeight - margin {
                    newPage()
                }
            }

            func drawLine(at yPos: CGFloat) {
                let path = UIBezierPath()
                path.move(to: CGPoint(x: margin, y: yPos))
                path.addLine(to: CGPoint(x: margin + contentWidth, y: yPos))
                UIColor(white: 0.78, alpha: 1).setStroke()
                path.lineWidth = 0.5
                path.stroke()
            }

            let titleFont = UIFont.boldSystemFont(ofSize: 20)
            let sectionFont = UIFont.boldSystemFont(ofSize: 14)
            let headerFont = UIFont.boldSystemFont(ofSize: 9)
            let bodyFont = UIFont.systemFont(ofSize: 10)
            let bodyBoldFont = UIFont.boldSystemFont(ofSize: 10)
            let smallFont = UIFont.systemFont(ofSize: 8)
            let smallItalicFont = UIFont.italicSystemFont(ofSize: 8)

            let darkColor = UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 1)
            let grayColor = UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 0.55)
            let lightGray = UIColor(red: 26/255, green: 26/255, blue: 26/255, alpha: 0.35)

            // MARK: - Cover / Header
            newPage()

            "AVIA HOMES".draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 10),
                .foregroundColor: grayColor,
                .kern: 3.0 as NSNumber
            ])
            y += 20

            "Client Selections Summary".draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: titleFont, .foregroundColor: darkColor
            ])
            y += 30

            let infoLines = [
                "Client: \(clientName)",
                "Spec Range: \(specTier.capitalized)",
                "Generated: \(Date.now.formatted(date: .long, time: .shortened))",
                "Spec Items: \(groupedSelections.flatMap(\.items).count)  |  Colour Selections: \(colourSelections.count)"
            ]
            for line in infoLines {
                line.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                    .font: bodyFont, .foregroundColor: grayColor
                ])
                y += 16
            }
            y += 10
            drawLine(at: y)
            y += 16

            // MARK: - Spec Range Section
            check(30)
            "SPECIFICATION RANGE SELECTIONS".draw(at: CGPoint(x: margin, y: y), withAttributes: [
                .font: sectionFont, .foregroundColor: darkColor
            ])
            y += 24

            let colItem: CGFloat = margin
            let colType: CGFloat = margin + contentWidth * 0.55
            let colClient: CGFloat = margin + contentWidth * 0.72
            let colAdmin: CGFloat = margin + contentWidth * 0.85

            for group in groupedSelections {
                check(40)
                group.category.uppercased().draw(at: CGPoint(x: margin, y: y), withAttributes: [
                    .font: headerFont, .foregroundColor: grayColor, .kern: 1.0 as NSNumber
                ])
                y += 14
                drawLine(at: y)
                y += 6

                // Table header
                "Item".draw(at: CGPoint(x: colItem, y: y), withAttributes: [.font: headerFont, .foregroundColor: lightGray])
                "Type".draw(at: CGPoint(x: colType, y: y), withAttributes: [.font: headerFont, .foregroundColor: lightGray])
                "Client".draw(at: CGPoint(x: colClient, y: y), withAttributes: [.font: headerFont, .foregroundColor: lightGray])
                "Admin".draw(at: CGPoint(x: colAdmin, y: y), withAttributes: [.font: headerFont, .foregroundColor: lightGray])
                y += 14

                for item in group.items {
                    check(36)

                    let nameStr = NSAttributedString(string: item.snapshotName, attributes: [
                        .font: bodyBoldFont, .foregroundColor: darkColor
                    ])
                    let nameRect = CGRect(x: colItem, y: y, width: colType - colItem - 8, height: 14)
                    nameStr.draw(with: nameRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)

                    item.selectionType.displayLabel.draw(at: CGPoint(x: colType, y: y), withAttributes: [
                        .font: smallFont, .foregroundColor: item.selectionType == .included ? grayColor : UIColor(red: 55/255, green: 51/255, blue: 43/255, alpha: 0.8)
                    ])

                    let clientMark = item.clientConfirmed ? "✓" : "—"
                    clientMark.draw(at: CGPoint(x: colClient + 6, y: y), withAttributes: [
                        .font: bodyFont, .foregroundColor: item.clientConfirmed ? UIColor(red: 142/255, green: 155/255, blue: 146/255, alpha: 1) : lightGray
                    ])

                    let adminMark = item.adminConfirmed ? "✓" : "—"
                    adminMark.draw(at: CGPoint(x: colAdmin + 6, y: y), withAttributes: [
                        .font: bodyFont, .foregroundColor: item.adminConfirmed ? UIColor(red: 142/255, green: 155/255, blue: 146/255, alpha: 1) : lightGray
                    ])

                    y += 14

                    let descRect = CGRect(x: colItem + 4, y: y, width: colType - colItem - 12, height: 12)
                    let descStr = NSAttributedString(string: item.snapshotDescription, attributes: [
                        .font: smallFont, .foregroundColor: grayColor
                    ])
                    descStr.draw(with: descRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
                    y += 14

                    if let notes = item.clientNotes, !notes.isEmpty {
                        "Client: \(notes)".draw(at: CGPoint(x: colItem + 4, y: y), withAttributes: [
                            .font: smallItalicFont, .foregroundColor: grayColor
                        ])
                        y += 10
                    }
                    if let notes = item.adminNotes, !notes.isEmpty {
                        "Admin: \(notes)".draw(at: CGPoint(x: colItem + 4, y: y), withAttributes: [
                            .font: smallItalicFont, .foregroundColor: UIColor(red: 142/255, green: 155/255, blue: 146/255, alpha: 1)
                        ])
                        y += 10
                    }
                    if let cost = item.upgradeCost, (item.selectionType == .upgradeRequested || item.selectionType == .upgradeCosted || item.selectionType == .upgradeAccepted || item.selectionType == .upgradeApproved) {
                        let costStr = "Upgrade cost: $\(String(format: "%.2f", cost))\(item.upgradeCostNote.map { " — \($0)" } ?? "")"
                        costStr.draw(at: CGPoint(x: colItem + 4, y: y), withAttributes: [
                            .font: smallItalicFont, .foregroundColor: UIColor(red: 55/255, green: 51/255, blue: 43/255, alpha: 0.8)
                        ])
                        y += 10
                    }

                    y += 4
                }
                y += 8
            }

            // MARK: - Colour Selections Section
            if !colourSelections.isEmpty {
                check(40)
                y += 10
                drawLine(at: y)
                y += 16

                "COLOUR SELECTIONS".draw(at: CGPoint(x: margin, y: y), withAttributes: [
                    .font: sectionFont, .foregroundColor: darkColor
                ])
                y += 24

                let colColour: CGFloat = margin
                let colCat: CGFloat = margin + contentWidth * 0.4
                let colOpt: CGFloat = margin + contentWidth * 0.65
                let colStatus: CGFloat = margin + contentWidth * 0.85

                "Category".draw(at: CGPoint(x: colColour, y: y), withAttributes: [.font: headerFont, .foregroundColor: lightGray])
                "Option".draw(at: CGPoint(x: colCat, y: y), withAttributes: [.font: headerFont, .foregroundColor: lightGray])
                "Brand".draw(at: CGPoint(x: colOpt, y: y), withAttributes: [.font: headerFont, .foregroundColor: lightGray])
                "Status".draw(at: CGPoint(x: colStatus, y: y), withAttributes: [.font: headerFont, .foregroundColor: lightGray])
                y += 14
                drawLine(at: y)
                y += 6

                for cs in colourSelections {
                    check(22)

                    let cat = catalog.allColourCategories.first { $0.id == cs.colourCategoryId }
                    let opt = cat?.options.first { $0.id == cs.colourOptionId }

                    let catName = cat?.name ?? cs.colourCategoryId
                    let optName = opt?.name ?? cs.colourOptionId
                    let brand = opt?.brand ?? ""
                    let status = cs.selectionStatus.rawValue.capitalized

                    let catRect = CGRect(x: colColour, y: y, width: colCat - colColour - 4, height: 14)
                    NSAttributedString(string: catName, attributes: [.font: bodyBoldFont, .foregroundColor: darkColor])
                        .draw(with: catRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)

                    let optRect = CGRect(x: colCat, y: y, width: colOpt - colCat - 4, height: 14)
                    NSAttributedString(string: optName, attributes: [.font: bodyFont, .foregroundColor: darkColor])
                        .draw(with: optRect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)

                    brand.draw(at: CGPoint(x: colOpt, y: y), withAttributes: [
                        .font: smallFont, .foregroundColor: grayColor
                    ])

                    let statusColor: UIColor = switch cs.selectionStatus {
                    case .approved: .systemGreen
                    case .submitted: .systemOrange
                    default: lightGray
                    }
                    status.draw(at: CGPoint(x: colStatus, y: y), withAttributes: [
                        .font: smallFont, .foregroundColor: statusColor
                    ])

                    y += 18
                }
            }

            // MARK: - Footer on last page
            y = pageHeight - margin
            drawLine(at: y - 14)
            "AVIA Homes — Confidential".draw(at: CGPoint(x: margin, y: y - 10), withAttributes: [
                .font: UIFont.systemFont(ofSize: 7), .foregroundColor: lightGray
            ])
        }

        return url
    }
}
