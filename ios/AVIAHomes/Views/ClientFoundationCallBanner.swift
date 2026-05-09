import SwiftUI
import Combine

/// Client-facing banner for the Foundation Call. Two states:
/// 1) Scheduled — shows live countdown + Join button.
/// 2) Not scheduled — shows a prominent CTA so the client can book a
///    Cal.com video call with the AVIA team themselves.
///
/// Subscribes to live updates on `client_foundation_calls` so it appears/updates
/// the moment the Cal.com webhook fires — no refresh required.
struct ClientFoundationCallBanner: View {
    let clientId: String
    var clientFullName: String = ""
    var clientEmail: String = ""

    @State private var call: FoundationCall?
    @State private var now: Date = .now
    @State private var isBooking: Bool = false

    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private enum BannerMode {
        case scheduled, schedule, hidden
    }

    private var mode: BannerMode {
        if let call {
            switch call.status {
            case .scheduled:
                if let when = call.scheduledAt, when.timeIntervalSince(now) <= -60 * 30 {
                    return .hidden // hide 30 min after start
                }
                return .scheduled
            case .completed:
                return .hidden
            default:
                return .schedule
            }
        }
        return .schedule
    }

    private var isVisible: Bool { mode != .hidden }

    private var meetingURL: URL? {
        guard let raw = call?.meetingURL?.trimmingCharacters(in: .whitespaces),
              !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    private var countdownLabel: String {
        guard let when = call?.scheduledAt else { return "" }
        let delta = when.timeIntervalSince(now)
        if delta <= 0 {
            return "Starting now"
        }
        let minutes = Int(delta / 60)
        if minutes < 60 {
            return "Starts in \(minutes) min"
        }
        let hours = Int(delta / 3600)
        if hours < 24 {
            let mins = minutes - hours * 60
            return mins > 0 ? "Starts in \(hours)h \(mins)m" : "Starts in \(hours)h"
        }
        let days = Int(delta / 86400)
        return days == 1 ? "Tomorrow at \(when.formatted(date: .omitted, time: .shortened))"
                         : "In \(days) days · \(when.formatted(date: .abbreviated, time: .shortened))"
    }

    private var canJoinNow: Bool {
        guard let when = call?.scheduledAt, meetingURL != nil else { return false }
        // Allow join 10 minutes before the call.
        return when.timeIntervalSince(now) <= 60 * 10
    }

    var body: some View {
        Group {
            switch mode {
            case .scheduled:
                scheduledContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            case .schedule:
                scheduleCTA
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
            case .hidden:
                EmptyView()
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isVisible)
        .task(id: clientId) {
            await load()
            SupabaseService.shared.subscribeToFoundationCalls {
                Task { @MainActor in await load() }
            }
        }
        .onReceive(ticker) { value in
            now = value
        }
    }

    // MARK: - Schedule CTA (no upcoming call)

    private var scheduleCTA: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(AVIATheme.timelessBrown)
                .frame(height: 4)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "video.badge.plus")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(width: 36, height: 36)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("BOOK A CALL")
                            .font(.neueCaption2Medium)
                            .tracking(1.2)
                            .foregroundStyle(AVIATheme.timelessBrown)

                        Text("Schedule your Foundation Call")
                            .font(.neueCorpMedium(20))
                            .foregroundStyle(AVIATheme.textPrimary)
                            .lineLimit(2)

                        Text("Pick a time that suits you for a 30-minute video call with our team.")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                Button {
                    openBooking()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.neueSubheadlineMedium)
                        Text("Schedule a Call")
                            .font(.neueCorpMedium(16))
                        Spacer()
                        Image(systemName: "arrow.up.right.square.fill")
                            .font(.neueSubheadline)
                            .opacity(0.9)
                    }
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .frame(maxWidth: .infinity)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isBooking)

                if call?.status == .pending,
                   call?.notes?.contains("opened") == true {
                    HStack(spacing: 6) {
                        Image(systemName: "hourglass")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text("Waiting for your booking to confirm…")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                }
            }
            .padding(16)
        }
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AVIATheme.timelessBrown.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: AVIATheme.timelessBrown.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    private func openBooking() {
        let trimmedName = clientFullName.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = clientEmail.trimmingCharacters(in: .whitespaces)
        let notes = "AVIA Foundation Call — Client: \(trimmedName.isEmpty ? trimmedEmail : trimmedName)"
        guard let url = CalComService.bookingURL(
            name: trimmedName.isEmpty ? nil : trimmedName,
            email: trimmedEmail.isEmpty ? nil : trimmedEmail,
            notes: notes,
            clientId: clientId
        ) else { return }

        // Optimistically create a pending record so the webhook can reconcile
        // by client_id + cal_booking_uid.
        if call == nil {
            let pending = FoundationCall(
                id: UUID().uuidString,
                clientId: clientId,
                organizerId: nil,
                status: .pending,
                scheduledAt: nil,
                durationMinutes: 30,
                meetingURL: nil,
                calBookingId: nil,
                calBookingUid: nil,
                calEventType: nil,
                attendeeEmail: trimmedEmail.isEmpty ? nil : trimmedEmail,
                attendeeName: trimmedName.isEmpty ? nil : trimmedName,
                notes: "Booking link opened by client",
                createdAt: .now,
                updatedAt: .now
            )
            call = pending
            isBooking = true
            Task {
                await SupabaseService.shared.upsertFoundationCall(pending)
                await MainActor.run { isBooking = false }
            }
        }

        UIApplication.shared.open(url)
    }

    // MARK: - Scheduled content

    private var scheduledContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(AVIATheme.timelessBrown)
                .frame(height: 4)
                .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "video.fill")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(width: 36, height: 36)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("FOUNDATION CALL")
                            .font(.neueCaption2Medium)
                            .tracking(1.2)
                            .foregroundStyle(AVIATheme.timelessBrown)

                        Text(headline)
                            .font(.neueCorpMedium(20))
                            .foregroundStyle(AVIATheme.textPrimary)
                            .lineLimit(2)

                        if let when = call?.scheduledAt {
                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.neueCaption2)
                                Text(when.formatted(date: .abbreviated, time: .shortened))
                                    .font(.neueCaption)
                            }
                            .foregroundStyle(AVIATheme.textSecondary)
                        }
                    }

                    Spacer()

                    Text(countdownLabel.uppercased())
                        .font(.neueCaption2Medium)
                        .tracking(0.6)
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AVIATheme.timelessBrown.opacity(0.12))
                        .clipShape(.capsule)
                        .fixedSize()
                }

                if let url = meetingURL {
                    joinButton(url: url)
                } else {
                    awaitingLinkRow
                }

                if let attendee = call?.attendeeName, !attendee.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text("With \(attendee)")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                }
            }
            .padding(16)
        }
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(AVIATheme.timelessBrown.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: AVIATheme.timelessBrown.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    private var headline: String {
        if canJoinNow { return "Your call is ready — join now" }
        return "Your Foundation Call is scheduled"
    }

    private func joinButton(url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                Image(systemName: canJoinNow ? "video.fill" : "calendar.badge.clock")
                    .font(.neueSubheadlineMedium)
                Text(canJoinNow ? "Join Video Call" : "View Meeting Link")
                    .font(.neueCorpMedium(16))
                Spacer()
                Image(systemName: "arrow.up.right.square.fill")
                    .font(.neueSubheadline)
                    .opacity(0.9)
            }
            .foregroundStyle(AVIATheme.aviaWhite)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .background(AVIATheme.primaryGradient)
            .clipShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var awaitingLinkRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "hourglass")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
            Text("We'll send your meeting link here as soon as it's confirmed.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AVIATheme.surfaceElevated)
        .clipShape(.rect(cornerRadius: 10))
    }

    private func load() async {
        guard !clientId.isEmpty else { return }
        let latest = await SupabaseService.shared.fetchLatestFoundationCall(clientId: clientId)
        call = latest
    }
}
