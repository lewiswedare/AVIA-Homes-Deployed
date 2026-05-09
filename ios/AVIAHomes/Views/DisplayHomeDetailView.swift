import SwiftUI

struct DisplayHomeDetailView: View {
    let home: DisplayHome

    @Environment(AppViewModel.self) private var viewModel
    @State private var showBookingSheet = false
    @State private var selectedImageIndex = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroGallery
                content
            }
        }
        .ignoresSafeArea(edges: [.top, .horizontal])
        .background(AVIATheme.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(home.name)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bookingCTA
        }
        .sheet(isPresented: $showBookingSheet) {
            BookDisplayHomeVisitSheet(home: home)
        }
    }

    // MARK: - Hero

    private var heroGallery: some View {
        Color(AVIATheme.surfaceElevated)
            .frame(height: 360)
            .overlay {
                if home.imageURLs.isEmpty {
                    Image(systemName: "house.lodge.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(AVIATheme.timelessBrown.opacity(0.25))
                } else {
                    TabView(selection: $selectedImageIndex) {
                        ForEach(Array(home.imageURLs.enumerated()), id: \.offset) { idx, urlString in
                            if let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } else if phase.error != nil {
                                        Image(systemName: "photo")
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    } else {
                                        ProgressView()
                                    }
                                }
                                .tag(idx)
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: home.imageURLs.count > 1 ? .always : .never))
                }
            }
            .allowsHitTesting(true)
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [AVIATheme.background.opacity(0), AVIATheme.background],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 80)
                .allowsHitTesting(false)
            }
            .clipped()
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 24) {
            titleSection
            statsRow
            if !home.openingHours.isEmpty || !home.contactPhone.isEmpty {
                infoCard
            }
            if !home.description.isEmpty {
                aboutSection
            }
            if !home.features.isEmpty {
                featuresSection
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 32)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(home.name)
                .font(.neueCorpMedium(28))
                .foregroundStyle(AVIATheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !home.estate.isEmpty {
                Text(home.estate.uppercased())
                    .font(.neueCorpMedium(10))
                    .kerning(0.8)
                    .foregroundStyle(AVIATheme.timelessBrown)
            }

            if !home.address.isEmpty || !home.suburb.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text([home.address, home.suburb].filter { !$0.isEmpty }.joined(separator: ", "))
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .font(.neueCaption)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(value: "\(home.bedrooms)", label: "Beds", icon: "bed.double.fill")
            statCard(value: "\(home.bathrooms)", label: "Baths", icon: "shower.fill")
            statCard(value: "\(home.garages)", label: "Garage", icon: "car.fill")
            if let sqm = home.squareMeters, sqm > 0 {
                statCard(value: "\(Int(sqm))", label: "m²", icon: "ruler")
            }
        }
    }

    private func statCard(value: String, label: String, icon: String) -> some View {
        BentoCard(cornerRadius: 11) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.neueCorp(14))
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .frame(width: 30, height: 30)
                    .background(AVIATheme.timelessBrown.opacity(0.1))
                    .clipShape(Circle())
                Text(value)
                    .font(.neueCorpMedium(16))
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(label)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
        }
    }

    private var infoCard: some View {
        BentoCard(cornerRadius: 13) {
            VStack(spacing: 0) {
                if !home.openingHours.isEmpty {
                    HStack(spacing: 12) {
                        BentoIconCircle(icon: "clock.fill", color: AVIATheme.timelessBrown)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Opening Hours")
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text(home.openingHours)
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                }

                if !home.openingHours.isEmpty && !home.contactPhone.isEmpty {
                    Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1).padding(.leading, 64)
                }

                if !home.contactPhone.isEmpty, let phoneURL = URL(string: "tel:\(home.contactPhone.filter { !$0.isWhitespace })") {
                    Link(destination: phoneURL) {
                        HStack(spacing: 12) {
                            BentoIconCircle(icon: "phone.fill", color: AVIATheme.success)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Call the Display Home")
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text(home.contactPhone)
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                        .padding(14)
                    }
                }
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ABOUT THIS DISPLAY")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)
            BentoCard(cornerRadius: 13) {
                Text(home.description)
                    .font(.neueSubheadline)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FEATURES")
                .font(.neueCaption2Medium)
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)
            BentoCard(cornerRadius: 13) {
                VStack(spacing: 0) {
                    ForEach(Array(home.features.enumerated()), id: \.offset) { idx, feature in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(AVIATheme.timelessBrown)
                                .frame(width: 28, height: 28)
                                .background(AVIATheme.timelessBrown.opacity(0.08))
                                .clipShape(Circle())
                            Text(feature)
                                .font(.neueSubheadline)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        if idx < home.features.count - 1 {
                            Rectangle()
                                .fill(AVIATheme.surfaceBorder)
                                .frame(height: 1)
                                .padding(.leading, 56)
                        }
                    }
                }
            }
        }
    }

    private var bookingCTA: some View {
        VStack(spacing: 0) {
            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
            Button {
                showBookingSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.neueSubheadlineMedium)
                    Text("Schedule a Visit")
                        .font(.neueSubheadlineMedium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .foregroundStyle(AVIATheme.aviaWhite)
                .background(AVIATheme.primaryGradient)
                .clipShape(.rect(cornerRadius: 11))
            }
            .buttonStyle(.pressable(.prominent))
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
        .background(AVIATheme.background)
    }
}

// MARK: - Booking Sheet

struct BookDisplayHomeVisitSheet: View {
    let home: DisplayHome
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var viewModel

    @State private var requestedAt: Date = Self.defaultSlot()
    @State private var partySize: Int = 2
    @State private var attendeeName: String = ""
    @State private var attendeeEmail: String = ""
    @State private var attendeePhone: String = ""
    @State private var notes: String = ""
    @State private var isSubmitting = false
    @State private var error: String?
    @State private var didSubmit = false

    private static func defaultSlot() -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: .now.addingTimeInterval(86_400))
        comps.hour = 11
        comps.minute = 0
        return cal.date(from: comps) ?? .now.addingTimeInterval(86_400)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Preferred date & time", selection: $requestedAt, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    Stepper("Party size: \(partySize)", value: $partySize, in: 1...10)
                } header: { Text("When would you like to visit?") }
                footer: {
                    if !home.openingHours.isEmpty {
                        Text("Display home hours: \(home.openingHours)")
                    }
                }

                Section("Your details") {
                    TextField("Full name", text: $attendeeName)
                        .textContentType(.name)
                    TextField("Email", text: $attendeeEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textContentType(.emailAddress)
                    TextField("Phone", text: $attendeePhone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }

                Section("Notes for the team (optional)") {
                    TextField("Anything we should know?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if let error {
                    Section {
                        Text(error)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.destructive)
                    }
                }
            }
            .navigationTitle("Book a Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting { ProgressView().controlSize(.small) } else { Text("Request").fontWeight(.semibold) }
                    }
                    .disabled(isSubmitting || !canSubmit)
                }
            }
            .onAppear { prefillFromProfile() }
            .alert("Visit requested", isPresented: $didSubmit) {
                Button("OK") { dismiss() }
            } message: {
                Text("We'll confirm your visit to \(home.name) shortly. You can track its status in My Visits.")
            }
        }
    }

    private var canSubmit: Bool {
        !attendeeName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !attendeeEmail.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func prefillFromProfile() {
        let user = viewModel.currentUser
        if attendeeName.isEmpty { attendeeName = user.fullName }
        if attendeeEmail.isEmpty { attendeeEmail = user.email }
        if attendeePhone.isEmpty { attendeePhone = user.phone }
    }

    private func submit() async {
        error = nil
        guard !viewModel.currentUser.id.isEmpty else {
            error = "You must be signed in to request a visit."
            return
        }
        isSubmitting = true
        defer { isSubmitting = false }

        let visit = DisplayHomeVisit(
            id: UUID().uuidString,
            displayHomeId: home.id,
            clientId: viewModel.currentUser.id,
            requestedAt: requestedAt,
            durationMinutes: 45,
            status: .pending,
            attendeeName: attendeeName.trimmingCharacters(in: .whitespacesAndNewlines),
            attendeeEmail: attendeeEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            attendeePhone: attendeePhone.trimmingCharacters(in: .whitespacesAndNewlines),
            partySize: partySize,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            assignedStaffId: nil,
            adminNotes: "",
            confirmedAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            createdAt: .now,
            updatedAt: .now
        )

        let ok = await viewModel.bookDisplayHomeVisit(visit)
        if ok {
            didSubmit = true
        } else {
            error = "Couldn't save your request. Please try again."
        }
    }
}
