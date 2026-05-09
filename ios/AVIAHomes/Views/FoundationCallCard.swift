import SwiftUI

/// Primary CTA card in the CRM for booking & tracking the Foundation Call —
/// AVIA's first-conversion video call (Cal.com).
struct FoundationCallCard: View {
    let client: ClientUser
    let currentUserId: String
    @Binding var call: FoundationCall?
    var onChange: () -> Void

    @State private var showSchedule: Bool = false
    @State private var showLogResult: Bool = false
    @State private var manualScheduledAt: Date = .now.addingTimeInterval(86400)
    @State private var manualMeetingURL: String = ""
    @State private var manualNotes: String = ""
    @State private var resultStatus: FoundationCallStatus = .completed
    @State private var openingURL: URL?

    private var status: FoundationCallStatus { call?.status ?? .pending }
    private var headerTitle: String {
        switch status {
        case .pending: return "Book Foundation Call"
        case .scheduled: return call?.isUpcoming == true ? "Foundation Call Scheduled" : "Foundation Call Due"
        case .completed: return "Foundation Call Completed"
        case .cancelled: return "Foundation Call Cancelled"
        case .noShow: return "Foundation Call — No Show"
        case .rescheduled: return "Foundation Call Rescheduled"
        }
    }

    private var subtitle: String {
        switch status {
        case .pending:
            return "AVIA's primary conversion goal. Book a 30-minute Cal.com video call with this client."
        case .scheduled:
            if let when = call?.scheduledAt {
                return "Scheduled for \(when.formatted(date: .abbreviated, time: .shortened)) (\(when.formatted(.relative(presentation: .named))))"
            }
            return "Scheduled — date pending"
        case .completed:
            if let when = call?.scheduledAt {
                return "Completed \(when.formatted(.relative(presentation: .named)))."
            }
            return "Completed."
        case .cancelled: return "Call was cancelled. Reach out to reschedule."
        case .noShow: return "Client did not attend. Follow up to reschedule."
        case .rescheduled: return "Call rescheduled — see latest time below."
        }
    }

    var body: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 14) {
                header
                if status == .scheduled, let url = call?.meetingURL, let meetingURL = URL(string: url) {
                    meetingLinkRow(url: meetingURL)
                }
                actions
                if !CalComService.isConfigured {
                    configHint
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showSchedule) { scheduleSheet }
        .sheet(isPresented: $showLogResult) { logResultSheet }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("FOUNDATION CALL")
                    .font(.neueCaption2Medium)
                    .tracking(1.2)
                    .foregroundStyle(AVIATheme.textTertiary)
                HStack(spacing: 8) {
                    Image(systemName: status.icon)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(status.color)
                    Text(headerTitle)
                        .font(.neueCorpMedium(18))
                        .foregroundStyle(AVIATheme.textPrimary)
                }
                Text(subtitle)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            statusBadge
        }
    }

    private var statusBadge: some View {
        Text(status.label.uppercased())
            .font(.neueCaption2Medium)
            .tracking(0.6)
            .foregroundStyle(status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.12))
            .clipShape(.capsule)
    }

    private func meetingLinkRow(url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 8) {
                Image(systemName: "video.fill")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.timelessBrown)
                Text("Join meeting")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
                Image(systemName: "arrow.up.right.square")
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AVIATheme.warmAccent)
            .clipShape(.rect(cornerRadius: 10))
        }
    }

    @ViewBuilder
    private var actions: some View {
        switch status {
        case .pending, .cancelled, .noShow, .rescheduled:
            VStack(spacing: 8) {
                primaryBookButton
                HStack(spacing: 8) {
                    secondaryButton(icon: "calendar.badge.plus", label: "Log Manually") {
                        prepareScheduleSheet()
                    }
                    if call != nil {
                        secondaryButton(icon: "pencil", label: "Update") {
                            prepareScheduleSheet()
                        }
                    }
                }
            }
        case .scheduled:
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    secondaryButton(icon: "checkmark.seal.fill", label: "Mark Done") {
                        resultStatus = .completed
                        showLogResult = true
                    }
                    secondaryButton(icon: "person.fill.xmark", label: "No Show") {
                        markStatus(.noShow)
                    }
                }
                HStack(spacing: 8) {
                    secondaryButton(icon: "arrow.triangle.2.circlepath", label: "Reschedule") {
                        prepareScheduleSheet()
                    }
                    secondaryButton(icon: "xmark.circle", label: "Cancel") {
                        markStatus(.cancelled)
                    }
                }
            }
        case .completed:
            HStack(spacing: 8) {
                secondaryButton(icon: "video.badge.plus", label: "Book Again") {
                    openCalCom()
                }
                secondaryButton(icon: "calendar.badge.plus", label: "Log Another") {
                    call = nil
                    prepareScheduleSheet()
                }
            }
        }
    }

    private var primaryBookButton: some View {
        Button {
            openCalCom()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "video.fill")
                    .font(.neueSubheadlineMedium)
                Text("Book on Cal.com")
                    .font(.neueCaptionMedium)
                Image(systemName: "arrow.up.right")
                    .font(.neueCaption)
            }
            .foregroundStyle(AVIATheme.aviaWhite)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(AVIATheme.primaryGradient)
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.neueCaption2)
                Text(label)
                    .font(.neueCaption2Medium)
            }
            .foregroundStyle(AVIATheme.timelessBrown)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10).stroke(AVIATheme.surfaceBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var configHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
            Text("Set EXPO_PUBLIC_CALCOM_BOOKING_URL to your team's Cal.com link.")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Actions

    private func openCalCom() {
        let notes = "AVIA Foundation Call — Client: \(client.fullName.isEmpty ? client.email : client.fullName)"
        guard let url = CalComService.bookingURL(
            name: client.fullName.isEmpty ? nil : client.fullName,
            email: client.email,
            notes: notes,
            clientId: client.id
        ) else { return }

        // Optimistically create a "pending" record so we can later reconcile
        // when the Cal.com webhook fires.
        if call == nil {
            let pending = FoundationCall(
                id: UUID().uuidString,
                clientId: client.id,
                organizerId: currentUserId,
                status: .pending,
                scheduledAt: nil,
                durationMinutes: 30,
                meetingURL: nil,
                calBookingId: nil,
                calBookingUid: nil,
                calEventType: nil,
                attendeeEmail: client.email,
                attendeeName: client.fullName,
                notes: "Booking link opened from CRM",
                createdAt: .now,
                updatedAt: .now
            )
            call = pending
            Task {
                await SupabaseService.shared.upsertFoundationCall(pending)
                onChange()
            }
        }

        UIApplication.shared.open(url)
    }

    private func prepareScheduleSheet() {
        manualScheduledAt = call?.scheduledAt ?? .now.addingTimeInterval(86400)
        manualMeetingURL = call?.meetingURL ?? ""
        manualNotes = call?.notes ?? ""
        showSchedule = true
    }

    private var scheduleSheet: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Scheduled", selection: $manualScheduledAt)
                }
                Section("Meeting Link") {
                    TextField("https://meet.google.com/… or Cal.com link", text: $manualMeetingURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Notes") {
                    TextField("Topics, attendees, prep…", text: $manualNotes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(call == nil ? "Schedule Call" : "Update Call")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showSchedule = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveManual() }
                }
            }
        }
    }

    private func saveManual() {
        var updated = call ?? FoundationCall(
            id: UUID().uuidString,
            clientId: client.id,
            organizerId: currentUserId,
            status: .scheduled,
            scheduledAt: manualScheduledAt,
            durationMinutes: 30,
            meetingURL: nil,
            calBookingId: nil,
            calBookingUid: nil,
            calEventType: nil,
            attendeeEmail: client.email,
            attendeeName: client.fullName,
            notes: nil,
            createdAt: .now,
            updatedAt: .now
        )
        updated.status = .scheduled
        updated.scheduledAt = manualScheduledAt
        updated.meetingURL = manualMeetingURL.trimmingCharacters(in: .whitespaces).isEmpty ? nil : manualMeetingURL
        updated.notes = manualNotes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : manualNotes
        updated.organizerId = currentUserId
        call = updated
        showSchedule = false
        Task {
            await SupabaseService.shared.upsertFoundationCall(updated)
            onChange()
        }
    }

    private var logResultSheet: some View {
        NavigationStack {
            Form {
                Section("Outcome") {
                    Picker("Status", selection: $resultStatus) {
                        Text("Completed").tag(FoundationCallStatus.completed)
                        Text("No Show").tag(FoundationCallStatus.noShow)
                        Text("Cancelled").tag(FoundationCallStatus.cancelled)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Summary") {
                    TextField("How did it go?", text: $manualNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showLogResult = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveResult() }
                }
            }
        }
    }

    private func saveResult() {
        guard var updated = call else { showLogResult = false; return }
        updated.status = resultStatus
        if !manualNotes.trimmingCharacters(in: .whitespaces).isEmpty {
            updated.notes = manualNotes
        }
        call = updated
        showLogResult = false
        Task {
            await SupabaseService.shared.upsertFoundationCall(updated)
            onChange()
        }
    }

    private func markStatus(_ status: FoundationCallStatus) {
        guard var updated = call else { return }
        updated.status = status
        call = updated
        Task {
            await SupabaseService.shared.upsertFoundationCall(updated)
            onChange()
        }
    }
}
