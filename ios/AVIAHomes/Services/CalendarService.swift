import EventKit
import SwiftUI

@Observable
class CalendarService {
    private let eventStore = EKEventStore()
    var calendarAccessGranted = false
    var reminderAccessGranted = false
    var showPermissionAlert = false
    var lastResultMessage: String?
    var showResultAlert = false

    func requestCalendarAccess() async {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            calendarAccessGranted = granted
            if !granted {
                showPermissionAlert = true
            }
        } catch {
            showPermissionAlert = true
        }
    }

    func requestReminderAccess() async {
        do {
            let granted = try await eventStore.requestFullAccessToReminders()
            reminderAccessGranted = granted
            if !granted {
                showPermissionAlert = true
            }
        } catch {
            showPermissionAlert = true
        }
    }

    func addToCalendar(item: ScheduleItem) async {
        await requestCalendarAccess()
        guard calendarAccessGranted else { return }

        let event = EKEvent(eventStore: eventStore)
        event.title = item.title
        event.notes = item.subtitle
        event.startDate = item.date
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: item.date)
        event.calendar = eventStore.defaultCalendarForNewEvents

        let alarm = EKAlarm(relativeOffset: -3600)
        event.addAlarm(alarm)

        do {
            try eventStore.save(event, span: .thisEvent)
            lastResultMessage = "Added to your calendar"
            showResultAlert = true
        } catch {
            lastResultMessage = "Could not save event"
            showResultAlert = true
        }
    }

    func setReminder(item: ScheduleItem) async {
        await requestReminderAccess()
        guard reminderAccessGranted else { return }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = item.title
        reminder.notes = item.subtitle
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: Calendar.current.date(byAdding: .hour, value: -1, to: item.date) ?? item.date
        )
        reminder.dueDateComponents = components

        let alarm = EKAlarm(absoluteDate: Calendar.current.date(byAdding: .hour, value: -1, to: item.date) ?? item.date)
        reminder.addAlarm(alarm)

        do {
            try eventStore.save(reminder, commit: true)
            lastResultMessage = "Reminder set"
            showResultAlert = true
        } catch {
            lastResultMessage = "Could not save reminder"
            showResultAlert = true
        }
    }
}
