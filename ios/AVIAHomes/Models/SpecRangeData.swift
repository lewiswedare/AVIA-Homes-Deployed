import Foundation

struct SpecRangeHighlight: Sendable {
    let icon: String
    let title: String
    let subtitle: String
    var iconImageURL: String? = nil
    var detailImageURL: String? = nil
}

struct SpecRangePartnerLogo: Sendable, Hashable {
    let name: String
    let imageURL: String
}

struct SpecRangeData: Sendable {
    let heroImageURL: String
    let summary: String
    let highlights: [SpecRangeHighlight]
    var partnerLogos: [SpecRangePartnerLogo] = []

    static let empty = SpecRangeData(heroImageURL: "", summary: "", highlights: [], partnerLogos: [])

    static func seedData(for tier: SpecTier) -> SpecRangeData {
        switch tier {
        case .volos:
            return SpecRangeData(
                heroImageURL: "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/2m8uxjn7nelckolf349xo.jpg",
                summary: "Everything you need to move into a beautifully finished home. The Volos range delivers quality fixtures, fittings and finishes that meet the high standards AVIA is known for. Designed for smart living, Volos provides a solid foundation of premium essentials without compromising on style or durability.",
                highlights: [
                    SpecRangeHighlight(icon: "countertop.fill", title: "Laminate Benchtops", subtitle: "Quality laminate kitchen benchtops from our standard range"),
                    SpecRangeHighlight(icon: "square.stack.3d.up.fill", title: "Vinyl Plank Flooring", subtitle: "Durable vinyl plank flooring to all living areas"),
                    SpecRangeHighlight(icon: "oven.fill", title: "600mm Appliance Suite", subtitle: "600mm oven, ceramic cooktop & rangehood included"),
                    SpecRangeHighlight(icon: "ruler.fill", title: "2,440mm Ceilings", subtitle: "Standard ceiling height throughout the home"),
                    SpecRangeHighlight(icon: "window.vertical.open", title: "Aluminium Windows", subtitle: "Aluminium windows with keyed locks as standard"),
                    SpecRangeHighlight(icon: "lightbulb.fill", title: "LED Downlights", subtitle: "Standard LED downlights throughout the home")
                ]
            )
        case .messina:
            return SpecRangeData(
                heroImageURL: "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/sxfdai5efw1uz7s7qqgmo.jpeg",
                summary: "Step up to stone benchtops, upgraded tapware and enhanced finishes throughout. The Messina range is our most popular specification, offering the perfect balance of luxury and value. Every detail has been carefully curated to elevate your everyday living experience.",
                highlights: [
                    SpecRangeHighlight(icon: "countertop.fill", title: "20mm Stone Benchtops", subtitle: "Beautiful stone kitchen benchtops from our standard range"),
                    SpecRangeHighlight(icon: "flame.fill", title: "900mm Gas Cooktop", subtitle: "900mm oven with 5-burner gas cooktop & rangehood"),
                    SpecRangeHighlight(icon: "square.stack.3d.up.fill", title: "Hybrid Vinyl Plank", subtitle: "Premium hybrid vinyl plank flooring to living areas"),
                    SpecRangeHighlight(icon: "cabinet.fill", title: "Two-Tone Cabinetry", subtitle: "Soft-close two-tone cabinetry throughout the kitchen"),
                    SpecRangeHighlight(icon: "shower.fill", title: "Semi-Frameless Showers", subtitle: "Semi-frameless shower screens in all wet areas"),
                    SpecRangeHighlight(icon: "ruler.fill", title: "2,590mm Ceilings", subtitle: "Higher ceilings for a more spacious feel")
                ]
            )
        case .portobello:
            return SpecRangeData(
                heroImageURL: "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/j4n8xaj2jlxo0wjxvkhr8.jpeg",
                summary: "The ultimate in home finishes. The Portobello range features designer selections, high-end materials and bespoke details that transform your home into a true showpiece. From premium stone benchtops to matte black fixtures and frameless glass, every element has been chosen to create an unforgettable living experience.",
                highlights: [
                    SpecRangeHighlight(icon: "countertop.fill", title: "Premium Stone Benchtops", subtitle: "20mm premium stone benchtops from our extended range"),
                    SpecRangeHighlight(icon: "flame.fill", title: "Pyrolytic Oven & Induction", subtitle: "900mm pyrolytic oven, induction cooktop, integrated rangehood & dishwasher"),
                    SpecRangeHighlight(icon: "drop.fill", title: "Matte Black Fixtures", subtitle: "Designer matte black tapware & fixtures throughout"),
                    SpecRangeHighlight(icon: "rectangle.portrait.fill", title: "Frameless Glass Showers", subtitle: "Premium frameless glass shower screens"),
                    SpecRangeHighlight(icon: "square.stack.3d.up.fill", title: "Premium Hybrid Flooring", subtitle: "Luxury hybrid flooring from extended range"),
                    SpecRangeHighlight(icon: "ruler.fill", title: "2,740mm Ceilings", subtitle: "Extra-high ceilings for grand proportions")
                ]
            )
        }
    }

    static func roomImages(for tier: SpecTier) -> [(name: String, imageURL: String)] {
        switch tier {
        case .volos:
            return [
                ("Kitchen", "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/2m8uxjn7nelckolf349xo.jpg"),
                ("Living Room", "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/sxfdai5efw1uz7s7qqgmo.jpeg"),
                ("Bathroom", "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/mddj1kprc8nfc5ujxb9sc.jpeg"),
                ("Bedroom", "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/tfj102uo1tuzrdd0hlm6b.jpeg"),
                ("Alfresco", "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t8j7r8vibjqzvubxzcnbg.jpeg"),
            ]
        case .messina:
            return [
                ("Kitchen", "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/sxfdai5efw1uz7s7qqgmo.jpeg"),
                ("Living Room", "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/j4n8xaj2jlxo0wjxvkhr8.jpeg"),
                ("Bathroom", "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/tfj102uo1tuzrdd0hlm6b.jpeg"),
                ("Bedroom", "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t8j7r8vibjqzvubxzcnbg.jpeg"),
                ("Alfresco", "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/mddj1kprc8nfc5ujxb9sc.jpeg"),
            ]
        case .portobello:
            return [
                ("Kitchen", "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/j4n8xaj2jlxo0wjxvkhr8.jpeg"),
                ("Living Room", "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/tfj102uo1tuzrdd0hlm6b.jpeg"),
                ("Bathroom", "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/mddj1kprc8nfc5ujxb9sc.jpeg"),
                ("Bedroom", "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/2m8uxjn7nelckolf349xo.jpg"),
                ("Alfresco", "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t8j7r8vibjqzvubxzcnbg.jpeg"),
            ]
        }
    }
}
