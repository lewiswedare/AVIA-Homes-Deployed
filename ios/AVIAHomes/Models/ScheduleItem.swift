import Foundation

nonisolated struct ScheduleItem: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let date: Date
    let type: ItemType

    nonisolated enum ItemType: String, Sendable {
        case siteVisit = "Site Visit"
        case walkthrough = "Walkthrough"
        case colourDue = "Colour Due"
        case inspection = "Inspection"
        case meeting = "Meeting"
        case handover = "Handover"
    }

    var iconColor: String {
        switch type {
        case .siteVisit: return "wrench.and.screwdriver.fill"
        case .walkthrough: return "figure.walk"
        case .colourDue: return "paintpalette.fill"
        case .inspection: return "checklist"
        case .meeting: return "person.2.fill"
        case .handover: return "key.fill"
        }
    }

    var isPast: Bool {
        date < Date()
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var timeUntil: (days: Int, hours: Int, minutes: Int, seconds: Int)? {
        guard date > Date() else { return nil }
        let interval = date.timeIntervalSince(Date())
        let totalSeconds = Int(interval)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return (days, hours, minutes, seconds)
    }

    static let samples: [ScheduleItem] = []
}
