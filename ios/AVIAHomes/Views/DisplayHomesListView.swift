import SwiftUI

struct DisplayHomesListView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var showMyBookings = false

    private var activeHomes: [DisplayHome] {
        viewModel.allDisplayHomes
            .filter { $0.isActive }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var myUpcomingCount: Int {
        viewModel.displayHomeVisits.filter { $0.isUpcoming }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroBanner

                if myUpcomingCount > 0 {
                    upcomingBookingsCard
                }

                if activeHomes.isEmpty {
                    emptyState
                } else {
                    homesGrid
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 32)
            .adaptiveWideWidth()
        }
        .background(AVIATheme.background)
        .navigationTitle("Display Homes")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if viewModel.currentRole == .client || viewModel.currentRole == .pending {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showMyBookings = true
                    } label: {
                        Image(systemName: "calendar.badge.clock")
                            .font(.neueSubheadline)
                    }
                }
            }
        }
        .sheet(isPresented: $showMyBookings) {
            NavigationStack {
                MyDisplayHomeBookingsView()
            }
        }
        .navigationDestination(for: DisplayHome.self) { home in
            DisplayHomeDetailView(home: home)
        }
        .task { await viewModel.reloadDisplayHomes() }
        .refreshable { await viewModel.reloadDisplayHomes() }
    }

    private var heroBanner: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "house.lodge.fill")
                        .font(.neueCorpMedium(16))
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .frame(width: 40, height: 40)
                        .background(AVIATheme.timelessBrown.opacity(0.12))
                        .clipShape(Circle())
                    Text("Visit a Display Home")
                        .font(.neueCorpMedium(20))
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                }
                Text("Step inside our completed homes to see finishes, layouts, and inclusions in person. Book a visit and one of our team will be there to walk you through.")
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .lineSpacing(3)
            }
            .padding(16)
        }
    }

    private var upcomingBookingsCard: some View {
        Button { showMyBookings = true } label: {
            BentoCard(cornerRadius: 13) {
                HStack(spacing: 12) {
                    BentoIconCircle(icon: "calendar.badge.checkmark", color: AVIATheme.timelessBrown)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(myUpcomingCount) upcoming visit\(myUpcomingCount == 1 ? "" : "s")")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("Tap to view your bookings")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .padding(14)
            }
        }
        .buttonStyle(.pressable(.subtle))
    }

    private var homesGrid: some View {
        VStack(spacing: 14) {
            ForEach(activeHomes) { home in
                NavigationLink(value: home) {
                    DisplayHomeCard(home: home)
                }
                .buttonStyle(.pressable(.subtle))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "house.lodge")
                .font(.system(size: 40))
                .foregroundStyle(AVIATheme.textTertiary)
            Text("No display homes available yet")
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textSecondary)
            Text("Check back soon — we'll have new display homes opening up.")
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Card

struct DisplayHomeCard: View {
    let home: DisplayHome

    var body: some View {
        BentoCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Color(AVIATheme.surfaceElevated)
                    .frame(height: 180)
                    .overlay {
                        if let urlString = home.primaryImageURL, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                if let image = phase.image {
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } else if phase.error != nil {
                                    Image(systemName: "house.lodge.fill")
                                        .font(.system(size: 36))
                                        .foregroundStyle(AVIATheme.timelessBrown.opacity(0.3))
                                } else {
                                    ProgressView()
                                }
                            }
                        } else {
                            Image(systemName: "house.lodge.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(AVIATheme.timelessBrown.opacity(0.3))
                        }
                    }
                    .allowsHitTesting(false)
                    .clipShape(.rect(cornerRadius: 14))
                    .overlay(alignment: .topTrailing) {
                        if !home.estate.isEmpty {
                            Text(home.estate.uppercased())
                                .font(.neueCorpMedium(9))
                                .kerning(0.6)
                                .foregroundStyle(AVIATheme.aviaWhite)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .padding(10)
                        }
                    }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(home.name)
                            .font(.neueCorpMedium(18))
                            .foregroundStyle(AVIATheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }

                    if !home.suburb.isEmpty || !home.address.isEmpty {
                        HStack(spacing: 5) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(AVIATheme.timelessBrown)
                            Text(home.suburb.isEmpty ? home.address : home.suburb)
                                .foregroundStyle(AVIATheme.textSecondary)
                                .lineLimit(1)
                        }
                        .font(.neueCaption)
                    }

                    HStack(spacing: 14) {
                        Label("\(home.bedrooms)", systemImage: "bed.double.fill")
                        Label("\(home.bathrooms)", systemImage: "shower.fill")
                        Label("\(home.garages)", systemImage: "car.fill")
                        if !home.openingHours.isEmpty {
                            Spacer(minLength: 4)
                            Label(home.openingHours, systemImage: "clock")
                                .lineLimit(1)
                        }
                    }
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                }
                .padding(14)
            }
        }
    }
}

// MARK: - My bookings

struct MyDisplayHomeBookingsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    private var sortedVisits: [DisplayHomeVisit] {
        viewModel.displayHomeVisits.sorted { $0.requestedAt > $1.requestedAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if sortedVisits.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 36))
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text("No bookings yet")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textSecondary)
                        Text("Pick a display home and tap “Schedule a Visit”.")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                } else {
                    ForEach(sortedVisits) { visit in
                        VisitClientRow(visit: visit, home: viewModel.allDisplayHomes.first { $0.id == visit.displayHomeId })
                    }
                }
            }
            .padding(16)
        }
        .background(AVIATheme.background)
        .navigationTitle("My Visits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.fontWeight(.semibold)
            }
        }
    }
}

private struct VisitClientRow: View {
    let visit: DisplayHomeVisit
    let home: DisplayHome?
    @Environment(AppViewModel.self) private var viewModel
    @State private var isCancelling = false

    var body: some View {
        BentoCard(cornerRadius: 13) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: visit.status.icon)
                        .font(.neueCorpMedium(14))
                        .foregroundStyle(visit.status.color)
                        .frame(width: 36, height: 36)
                        .background(visit.status.color.opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(home?.name ?? "Display home")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text(visit.requestedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }

                    Spacer()
                    StatusBadge(title: visit.status.label, color: visit.status.color)
                }

                if !visit.notes.isEmpty {
                    Text(visit.notes)
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }

                if visit.status == .pending || visit.status == .confirmed,
                   visit.requestedAt > .now {
                    Button(role: .destructive) {
                        Task {
                            isCancelling = true
                            var updated = visit
                            updated.status = .cancelled
                            updated.cancelledAt = .now
                            _ = await viewModel.updateDisplayHomeVisit(updated)
                            isCancelling = false
                        }
                    } label: {
                        if isCancelling {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Cancel Visit")
                                .font(.neueCaptionMedium)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .foregroundStyle(AVIATheme.destructive)
                    .background(AVIATheme.destructive.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 10))
                }
            }
            .padding(14)
        }
    }
}
