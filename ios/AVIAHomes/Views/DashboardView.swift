import SwiftUI
import EventKit
import Combine

struct DashboardView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(ColourSelectionViewModel.self) private var colourVM
    @Environment(CustomerJourneyViewModel.self) private var journeyVM
    @Binding var selectedTab: Int
    @State private var selectedSegment = 0
    @State private var calendarService = CalendarService()
    @State private var showScheduleSheet = false
    @State private var selectedScheduleItem: ScheduleItem?
    @State private var countdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var countdownTick: Int = 0
    @State private var showDesignDirectory: Bool = false
    @State private var showJourneyDetail: Bool = false
    @State private var showMyDesignPlan: Bool = false
    @State private var assignedStaffProfile: ClientUser?
    @State private var showGeneralMessage = false
    @State private var showContractSigning = false
    @State private var pendingContract: ContractSignatureRow?
    @State private var pendingContractAssignment: PackageAssignment?
    @State private var pendingContractPackage: HouseLandPackage?

    private let segments = ["My Home", "Discover"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    heroImage

                    VStack(spacing: 18) {
                        headerRow
                        segmentPicker
                        switch selectedSegment {
                        case 0:
                            overviewContent
                        case 1:
                            discoverContent
                        default:
                            overviewContent
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(AVIATheme.background)
            .navigationDestination(for: HomeDesign.self) { design in
                HomeDesignDetailView(design: design)
            }
            .navigationDestination(for: HouseLandPackage.self) { pkg in
                PackageDetailView(package: pkg)
            }
            .navigationDestination(for: LandEstate.self) { estate in
                EstateDetailView(estate: estate)
            }
            .navigationDestination(for: SpecTier.self) { tier in
                SpecRangeDetailView(tier: tier)
            }
            .navigationDestination(for: Facade.self) { facade in
                FacadeDetailView(facade: facade)
            }
            .hapticRefresh {
                await viewModel.refreshAllData()
            }
            .onReceive(countdownTimer) { _ in
                countdownTick += 1
            }
            .fullScreenCover(isPresented: $showDesignDirectory) {
                HomeDesignDirectoryView()
            }
            .navigationDestination(isPresented: $showMyDesignPlan) {
                MyDesignPlanView()
            }
            .sheet(isPresented: $showContractSigning) {
                if let assign = pendingContractAssignment, let pkg = pendingContractPackage {
                    ContractUploadView(assignment: assign, package: pkg)
                }
            }
            .sheet(isPresented: $showJourneyDetail) {
                BuildJourneyDetailView(
                    onNavigateToSpecs: { selectedTab = 1 },
                    onNavigateToColours: { selectedTab = 2 }
                )
            }
            .alert(calendarService.lastResultMessage ?? "", isPresented: $calendarService.showResultAlert) {
                Button("OK", role: .cancel) {}
            }
            .alert("Permission Required", isPresented: $calendarService.showPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please allow calendar or reminders access in Settings to add events.")
            }
            .confirmationDialog("Add to Schedule", isPresented: $showScheduleSheet, presenting: selectedScheduleItem) { item in
                Button("Add to Calendar") {
                    Task { await calendarService.addToCalendar(item: item) }
                }
                Button("Set Reminder") {
                    Task { await calendarService.setReminder(item: item) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { item in
                Text("\(item.title)\n\(item.date.formatted(date: .long, time: .shortened))")
            }
        }
    }

    private var heroImage: some View {
        Color(AVIATheme.surfaceElevated)
            .frame(height: 360)
            .overlay {
                Image("hero_facade")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: AVIATheme.timelessBrown.opacity(0.10), location: 0.20),
                        .init(color: AVIATheme.background.opacity(0.4), location: 0.45),
                        .init(color: AVIATheme.background.opacity(0.7), location: 0.65),
                        .init(color: AVIATheme.background.opacity(0.9), location: 0.8),
                        .init(color: AVIATheme.background, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 220)
            }
            .clipped()
    }

    private var headerRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image("AVIALogo")
                    .renderingMode(.template)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 24)
                    .foregroundStyle(AVIATheme.timelessBrown)
                Spacer()
                NavigationLink {
                    NotificationsView()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .frame(width: 36, height: 36)
                            .background(AVIATheme.cardBackground)
                            .clipShape(Circle())
                        if viewModel.notificationService.unreadCount > 0 {
                            Circle()
                                .fill(AVIATheme.destructive)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                NavigationLink {
                    ConversationsView()
                } label: {
                    Image(systemName: "message.fill")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(AVIATheme.cardBackground)
                        .clipShape(Circle())
                }
                Text(String(viewModel.currentUser.firstName.prefix(1)) + String(viewModel.currentUser.lastName.prefix(1)))
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.aviaWhite)
                    .frame(width: 36, height: 36)
                    .background(AVIATheme.brownGradient)
                    .clipShape(Circle())
            }

            Text(viewModel.currentUser.firstName.isEmpty ? "Welcome Home" : "Welcome Home, \(viewModel.currentUser.firstName)")
                .font(.neueCorpMedium(34))
                .foregroundStyle(AVIATheme.timelessBrown)
        }
    }

    private var segmentPicker: some View {
        HStack(spacing: 8) {
            ForEach(Array(segments.enumerated()), id: \.offset) { index, title in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        selectedSegment = index
                    }
                } label: {
                    Text(title)
                        .font(.neueSubheadlineMedium)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .foregroundStyle(selectedSegment == index ? AVIATheme.textPrimary : AVIATheme.textSecondary)
                        .background(selectedSegment == index ? AVIATheme.cardBackgroundAlt : AVIATheme.cardBackground)
                        .clipShape(Capsule())
                        .overlay {
                            if selectedSegment == index {
                                Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                            }
                        }
                }
            }
            Spacer()
        }
    }

    private var journeyCard: some View {
        BuildJourneyCard(
            onTapAction: { showJourneyDetail = true },
            onNavigateToSpecs: { selectedTab = 1 },
            onNavigateToColours: { selectedTab = 2 }
        )
    }

    private var packageCard: some View {
        NavigationLink {
            ClientPackageReviewView()
        } label: {
            BentoCard(cornerRadius: 16) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("My Package")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("View your accepted home & land package")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.neueCaption2Medium)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .padding(16)
            }
        }
    }

    private var overviewContent: some View {
        VStack(spacing: 16) {
            contractSigningBanner
            journeyCard
            packageCard
            staffContactSection
            generalMessageButton
            nextUpCountdownCard
            scheduleAndTasksRow
            dateAndBuildInfo
            statCards
            buildProgressGauge
            upcomingRemindersSection
            resourceUsageCard
            upcomingScheduleList
        }
        .task { await loadStaffContact() }
        .task { await loadPendingContract() }
    }

    @ViewBuilder
    private var staffContactSection: some View {
        if let staff = assignedStaffProfile {
            StaffContactCard(staffUser: staff)
        }
    }

    private var generalMessageButton: some View {
        Group {
            if assignedStaffProfile == nil {
                PremiumButton("Contact Us", icon: "message.fill", style: .secondary) {
                    showGeneralMessage = true
                }
                .sheet(isPresented: $showGeneralMessage) {
                    NavigationStack {
                        GeneralMessageSheet()
                    }
                }
            }
        }
    }

    private func loadStaffContact() async {
        guard let build = viewModel.clientBuildsForCurrentUser.first else { return }
        if build.handoverTriggeredAt != nil, let bsId = build.buildingSupportStaffId, !bsId.isEmpty {
            assignedStaffProfile = await SupabaseService.shared.fetchProfile(userId: bsId)
        } else if let pcId = build.preConstructionStaffId, !pcId.isEmpty {
            assignedStaffProfile = await SupabaseService.shared.fetchProfile(userId: pcId)
        }
    }

    private func loadPendingContract() async {
        let relevantStatuses: Set<String> = [
            "awaiting_contract",      // legacy / pre-upload
            "awaiting_signature",     // legacy / pre-upload
            "awaiting_confirmation"   // upload done, waiting for dual confirm
        ]
        for assign in viewModel.packageAssignments where relevantStatuses.contains(assign.contractStatus) {
            if assign.sharedWithClientIds.contains(viewModel.currentUser.id) {
                if let contract = await SupabaseService.shared.fetchContractSignature(forAssignment: assign.id) {
                    pendingContract = contract
                    pendingContractAssignment = assign
                    pendingContractPackage = viewModel.allPackages.first { $0.id == assign.packageId }
                    return
                }
            }
        }
    }

    @ViewBuilder
    private var contractSigningBanner: some View {
        if pendingContract != nil && pendingContractPackage != nil {
            Button {
                showContractSigning = true
            } label: {
                BentoCard(cornerRadius: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AVIATheme.warning.opacity(0.12))
                                .frame(width: 42, height: 42)
                            Image(systemName: "signature")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(AVIATheme.warning)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Contract Ready to Sign")
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text("Tap to review and sign your contract")
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    .padding(16)
                }
            }
            .buttonStyle(.pressable(.subtle))
        }
    }

    private var staffContactCard: some View {
        Color(AVIATheme.surfaceElevated)
            .overlay {
                Image("drew_photo")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .clipped()
                    .allowsHitTesting(false)
            }
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: AVIATheme.aviaBlack.opacity(0.3), location: 0.4),
                        .init(color: AVIATheme.aviaBlack.opacity(0.75), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Drew Holden")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)

                    Text("Pre-Site Coordinator")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.aviaWhite.opacity(0.7))

                    HStack(spacing: 6) {
                        if let phoneURL = URL(string: "tel:0468040280") {
                            Link(destination: phoneURL) {
                                Image(systemName: "phone.fill")
                                    .font(.neueCorp(10))
                                    .foregroundStyle(AVIATheme.aviaWhite)
                                    .frame(width: 28, height: 28)
                                    .background(AVIATheme.aviaWhite.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        }
                        if let mailURL = URL(string: "mailto:drew@aviahomes.com.au") {
                            Link(destination: mailURL) {
                                Image(systemName: "envelope.fill")
                                    .font(.neueCorp(10))
                                    .foregroundStyle(AVIATheme.aviaWhite)
                                    .frame(width: 28, height: 28)
                                    .background(AVIATheme.aviaWhite.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .clipShape(.rect(cornerRadius: 16))
            .contextMenu {
                Button {
                    if let url = URL(string: "tel:0468040280") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Call Drew", systemImage: "phone.fill")
                }
                Button {
                    if let url = URL(string: "mailto:drew@aviahomes.com.au") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("Email Drew", systemImage: "envelope.fill")
                }
            }
    }

    private var nextUpCountdownCard: some View {
        Group {
            if let next = viewModel.nextScheduleItem {
                let _ = countdownTick
                let remaining = next.timeUntil
                BentoCard(cornerRadius: 16) {
                    VStack(spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("NEXT UP")
                                    .font(.neueCaption2Medium)
                                    .kerning(1.2)
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                Text(next.title)
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                Text(next.date.formatted(date: .long, time: .shortened))
                                    .font(.neueCaption)
                                    .foregroundStyle(AVIATheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: next.icon)
                                .font(.neueCorpMedium(20))
                                .foregroundStyle(AVIATheme.timelessBrown)
                                .frame(width: 44, height: 44)
                                .background(AVIATheme.timelessBrown.opacity(0.1))
                                .clipShape(Circle())
                        }

                        if let r = remaining {
                            HStack(spacing: 6) {
                                CountdownUnit(value: r.days, label: "DAYS")
                                CountdownSeparator()
                                CountdownUnit(value: r.hours, label: "HRS")
                                CountdownSeparator()
                                CountdownUnit(value: r.minutes, label: "MIN")
                                CountdownSeparator()
                                CountdownUnit(value: r.seconds, label: "SEC")
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
                            .background(AVIATheme.surfaceElevated)
                            .clipShape(.rect(cornerRadius: 12))
                        }

                        HStack(spacing: 10) {
                            Button {
                                selectedScheduleItem = next
                                showScheduleSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "calendar.badge.plus")
                                        .font(.neueCorp(12))
                                    Text("Add to Calendar")
                                        .font(.neueCaptionMedium)
                                }
                                .foregroundStyle(AVIATheme.aviaWhite)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(AVIATheme.primaryGradient)
                                .clipShape(.rect(cornerRadius: 10))
                            }
                            .sensoryFeedback(.impact(flexibility: .soft), trigger: showScheduleSheet)

                            Button {
                                Task { await calendarService.setReminder(item: next) }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "bell.badge")
                                        .font(.neueCorp(12))
                                    Text("Remind Me")
                                        .font(.neueCaptionMedium)
                                }
                                .foregroundStyle(AVIATheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(AVIATheme.surfaceElevated)
                                .clipShape(.rect(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    private var scheduleAndTasksRow: some View {
        HStack(spacing: 12) {
            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("Schedule")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                    }
                    Text("\(viewModel.upcomingScheduleItems.count) Upcoming")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }

            VStack(spacing: 8) {
                if let first = viewModel.upcomingScheduleItems.first {
                    BentoCard(cornerRadius: 14) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: first.icon)
                                    .font(.neueCorp(10))
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                Text(first.type.rawValue)
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            StatusBadge(title: daysAwayLabel(first.date), color: AVIATheme.timelessBrown)
                        }
                        .padding(12)
                    }
                }

                if viewModel.upcomingScheduleItems.count > 1 {
                    let second = viewModel.upcomingScheduleItems[1]
                    BentoCard(cornerRadius: 14) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: second.icon)
                                    .font(.neueCorp(10))
                                    .foregroundStyle(AVIATheme.warning)
                                Text(second.type.rawValue)
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            StatusBadge(title: daysAwayLabel(second.date), color: AVIATheme.warning)
                        }
                        .padding(12)
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var dateAndBuildInfo: some View {
        HStack(spacing: 12) {
            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    let day = Calendar.current.component(.day, from: Date())
                    let month = Date().formatted(.dateTime.month(.wide))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(day)")
                            .font(.neueCorpMedium(40))
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text(month)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }

            Button {
                showMyDesignPlan = true
            } label: {
                BentoCard(cornerRadius: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text("My Home")
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(AVIATheme.timelessBrown)
                        }
                        Text(viewModel.currentUser.homeDesign)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statCards: some View {
        HStack(spacing: 12) {
            Button {
                selectedTab = 2
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(colourVM.completedCount)")
                            .font(.neueCorpMedium(36))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text("of \(colourVM.totalCount)")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    Text("Colour Selections")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(.rect(cornerRadius: 16))
                .shadow(color: AVIATheme.aviaBlack.opacity(0.06), radius: 8, y: 2)
            }

            NavigationLink {
                DocumentsView()
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(format: "%02d", viewModel.documents.count))
                        .font(.neueCorpMedium(36))
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("Active Documents")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AVIATheme.cardBackground)
                .clipShape(.rect(cornerRadius: 16))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var buildProgressGauge: some View {
        HStack(spacing: 12) {
            Button {
                selectedTab = 3
            } label: {
                BentoCard(cornerRadius: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Build Progress")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textSecondary)

                        if let stage = viewModel.currentBuildStage {
                            Text(stage.name)
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                        }

                        GaugeArc(progress: viewModel.overallProgress, color: AVIATheme.timelessBrown)
                            .frame(height: 100)

                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Circle().fill(AVIATheme.timelessBrown).frame(width: 6, height: 6)
                                Text("Complete")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }
                            HStack(spacing: 4) {
                                Circle().fill(AVIATheme.surfaceBorder).frame(width: 6, height: 6)
                                Text("Remaining")
                                    .font(.neueCaption2)
                                    .foregroundStyle(AVIATheme.textTertiary)
                            }
                        }

                        if let next = viewModel.nextMilestoneForCurrentUser {
                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)
                            HStack(spacing: 8) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(AVIATheme.timelessBrown)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Next Milestone")
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                    Text(next.title)
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(AVIATheme.textPrimary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }

            staffContactCard
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var upcomingRemindersSection: some View {
        let reminders = viewModel.upcomingReminders
        if !reminders.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("Upcoming Reminders")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    if viewModel.unreadReminders.count > 0 {
                        StatusBadge(title: "\(viewModel.unreadReminders.count)", color: AVIATheme.warning)
                    }
                }

                ForEach(reminders.prefix(3)) { reminder in
                    BentoCard(cornerRadius: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: reminder.isRead ? "bell" : "bell.badge.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(reminder.isRead ? AVIATheme.textTertiary : AVIATheme.timelessBrown)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(reminder.title)
                                    .font(.neueCaptionMedium)
                                    .foregroundStyle(reminder.isRead ? AVIATheme.textTertiary : AVIATheme.textPrimary)
                                if !reminder.message.isEmpty {
                                    Text(reminder.message)
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textSecondary)
                                        .lineLimit(2)
                                }
                                if let date = reminder.reminderDate {
                                    Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }
                            }

                            Spacer()

                            if !reminder.isRead {
                                Button {
                                    Task { await viewModel.markReminderRead(id: reminder.id) }
                                } label: {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(AVIATheme.timelessBrown)
                                }
                            }
                        }
                        .padding(14)
                    }
                }
            }
        }
    }

    private var resourceUsageCard: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Build Resource Overview")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("Last updated today")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    Spacer()
                }

                BentoCard(cornerRadius: 12) {
                    HStack(spacing: 0) {
                        ResourceMetric(value: "\(Int(viewModel.overallProgress * 100))%", label: "Progress")
                        ResourceMetric(value: "\(colourVM.completedCount)", label: "Selections")
                        ResourceMetric(value: "\(viewModel.openRequestCount)", label: "Open Requests")
                    }
                    .padding(.vertical, 14)
                }
                .background(AVIATheme.surfaceElevated)
                .clipShape(.rect(cornerRadius: 12))

                VStack(spacing: 6) {
                    HStack {
                        Text("Behind")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                        Spacer()
                        Text("On Track")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                    SegmentedProgressBar(progress: viewModel.overallProgress)
                        .frame(height: 16)
                }
            }
            .padding(16)
        }
    }

    private var upcomingScheduleList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.timelessBrown)
                Text("Upcoming Schedule")
                    .font(.neueCorpMedium(20))
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
            }

            ForEach(viewModel.upcomingScheduleItems) { item in
                let _ = countdownTick
                scheduleItemRow(item: item)
            }
        }
    }

    private func scheduleItemRow(item: ScheduleItem) -> some View {
        BentoCard(cornerRadius: 16) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .font(.neueCorpMedium(14))
                        .foregroundStyle(colorForType(item.type))
                        .frame(width: 36, height: 36)
                        .background(colorForType(item.type).opacity(0.12))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                            .lineLimit(1)
                        Text(item.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }

                    Spacer(minLength: 0)

                    if let r = item.timeUntil {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(compactCountdown(r))
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                                .monospacedDigit()
                            Text(daysAwayLabel(item.date))
                                .font(.neueCaption2)
                                .foregroundStyle(AVIATheme.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 10)

                Divider()
                    .padding(.horizontal, 14)

                HStack(spacing: 8) {
                    Button {
                        selectedScheduleItem = item
                        showScheduleSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.neueCorp(10))
                            Text("Calendar")
                                .font(.neueCaption2Medium)
                        }
                        .foregroundStyle(AVIATheme.timelessBrown)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(AVIATheme.timelessBrown.opacity(0.08))
                        .clipShape(Capsule())
                    }

                    Button {
                        Task { await calendarService.setReminder(item: item) }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bell")
                                .font(.neueCorp(10))
                            Text("Remind")
                                .font(.neueCaption2Medium)
                        }
                        .foregroundStyle(AVIATheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(AVIATheme.surfaceElevated)
                        .clipShape(Capsule())
                    }

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }

    private func colorForType(_ type: ScheduleItem.ItemType) -> Color {
        switch type {
        case .siteVisit: return AVIATheme.timelessBrown
        case .walkthrough: return AVIATheme.timelessBrown
        case .colourDue: return AVIATheme.warning
        case .inspection: return AVIATheme.success
        case .meeting: return AVIATheme.heritageBlue
        case .handover: return AVIATheme.timelessBrown
        }
    }

    private func daysAwayLabel(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        return "\(days) days"
    }

    private func compactCountdown(_ r: (days: Int, hours: Int, minutes: Int, seconds: Int)) -> String {
        if r.days > 0 {
            return String(format: "%dd %02dh %02dm", r.days, r.hours, r.minutes)
        }
        return String(format: "%02d:%02d:%02d", r.hours, r.minutes, r.seconds)
    }

    private var discoverContent: some View {
        DiscoverFeedView()
    }

    private var aboutUsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "About Us", icon: "info.circle.fill")

            VStack(spacing: 0) {
                Color(AVIATheme.aviaBlack)
                    .frame(height: 160)
                    .overlay {
                        AsyncImage(url: URL(string: "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t8j7r8vibjqzvubxzcnbg.jpeg")) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill).opacity(0.35)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .overlay {
                        VStack(spacing: 6) {
                            Image("AVIALogo")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 28)
                                .foregroundStyle(AVIATheme.aviaWhite)
                            Text("Building Homes Worth Living In")
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.aviaWhite.opacity(0.8))
                        }
                    }
                    .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))

                VStack(alignment: .leading, spacing: 12) {
                    Text("AVIA Homes is a boutique Queensland builder specialising in quality residential homes across the Gold Coast and Sunshine Coast. We combine innovative design with premium inclusions to deliver homes that exceed expectations.")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                        .lineSpacing(3)

                    HStack(spacing: 16) {
                        aboutStat(value: "500+", label: "Homes Built")
                        aboutStat(value: "15+", label: "Years Exp.")
                        aboutStat(value: "HIA", label: "Member")
                    }

                    Divider().overlay(AVIATheme.surfaceBorder)

                    if let capURL = URL(string: "https://www.aviahomes.com.au") {
                        Link(destination: capURL) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.fill")
                                    .font(.neueCaption2)
                                Text("Download Capability Statement")
                                    .font(.neueCaptionMedium)
                                Spacer()
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.neueSubheadlineMedium)
                            }
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(AVIATheme.primaryGradient)
                            .clipShape(.rect(cornerRadius: 12))
                        }
                    }
                }
                .padding(14)
            }
            .background(AVIATheme.cardBackground)
            .clipShape(.rect(cornerRadius: 16))
        }
    }

    private func aboutStat(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.neueCorpMedium(18))
                .foregroundStyle(AVIATheme.timelessBrown)
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private var facadesSlider: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Our Facades")
                    .font(.neueCorpMedium(24))
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(Array(facadeShowcaseItems.enumerated()), id: \.offset) { _, item in
                        facadeShowcaseCard(item: item)
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
    }

    private var facadeShowcaseItems: [(name: String, style: String, imageURL: String)] {
        viewModel.allFacades.prefix(6).map { ($0.name, $0.style, $0.heroImageURL) }
    }

    private func facadeShowcaseCard(item: (name: String, style: String, imageURL: String)) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(AVIATheme.surfaceElevated)
                .frame(width: 260, height: 325)
                .overlay {
                    AsyncImage(url: URL(string: item.imageURL)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            Image(systemName: "photo")
                                .font(.neueCorpMedium(24))
                                .foregroundStyle(AVIATheme.timelessBrown.opacity(0.25))
                        } else {
                            ProgressView()
                        }
                    }
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    Text(item.name.uppercased())
                        .font(.neueCorpMedium(9))
                        .kerning(0.8)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AVIATheme.aviaBlack.opacity(0.7))
                        .clipShape(Capsule())
                        .padding(10)
                }
                .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(item.style)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(12)
        }
        .frame(width: 260)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private var specRangesSlider: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Our Spec Ranges")
                    .font(.neueCorpMedium(24))
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(SpecTier.allCases) { tier in
                        NavigationLink(value: tier) {
                            specRangeCard(tier: tier)
                        }
                        .buttonStyle(.pressable(.subtle))
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
    }

    private func specRangeCard(tier: SpecTier) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(AVIATheme.surfaceElevated)
                .frame(width: 240, height: 300)
                .overlay {
                    AsyncImage(url: URL(string: specRangeImageURL(for: tier))) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else if phase.error != nil {
                            Text(tier.displayName)
                                .font(.neueCorpMedium(16))
                                .foregroundStyle(AVIATheme.timelessBrown.opacity(0.25))
                        } else {
                            ProgressView()
                        }
                    }
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [.clear, AVIATheme.aviaBlack.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 60)
                }
                .overlay(alignment: .bottomLeading) {
                    Text(tier.displayName)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .padding(10)
                }
                .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))

            VStack(alignment: .leading, spacing: 4) {
                Text(tier.tagline)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(specRangeDescription(for: tier))
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .lineLimit(2)
            }
            .padding(10)
        }
        .frame(width: 240)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func specRangeImageURL(for tier: SpecTier) -> String {
        switch tier {
        case .volos: "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/2m8uxjn7nelckolf349xo.jpg"
        case .messina: "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/sxfdai5efw1uz7s7qqgmo.jpeg"
        case .portobello: "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/j4n8xaj2jlxo0wjxvkhr8.jpeg"
        }
    }

    private func specRangeDescription(for tier: SpecTier) -> String {
        switch tier {
        case .volos: "Quality foundations for smart living"
        case .messina: "Step up to elevated comfort & style"
        case .portobello: "The ultimate in premium finishes"
        }
    }

    private var latestNewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Latest News")
                    .font(.neueCorpMedium(24))
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
            }

            if let featuredPost = viewModel.allBlogPosts.first {
                featuredBlogCard(post: featuredPost)
            }

            ForEach(viewModel.allBlogPosts.dropFirst()) { post in
                compactBlogRow(post: post)
            }
        }
    }

    private func featuredBlogCard(post: BlogPost) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color(AVIATheme.surfaceElevated)
                .frame(height: 180)
                .overlay {
                    AsyncImage(url: URL(string: post.imageURL)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))
                .overlay(alignment: .topLeading) {
                    AVIAChip(post.category.uppercased(), onLight: false)
                        .padding(12)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(post.title)
                    .font(.neueHeadline)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .lineLimit(2)

                Text(post.subtitle)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label(post.readTime, systemImage: "clock")
                    Label(post.date.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                }
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func compactBlogRow(post: BlogPost) -> some View {
        BentoCard(cornerRadius: 16) {
            HStack(spacing: 12) {
                Color(AVIATheme.surfaceElevated)
                    .frame(width: 72, height: 72)
                    .overlay {
                        AsyncImage(url: URL(string: post.imageURL)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(post.category.uppercased())
                        .font(.neueCorpMedium(9))
                        .kerning(0.6)
                        .foregroundStyle(AVIATheme.timelessBrown)

                    Text(post.title)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(post.readTime)
                        Text("·")
                        Text(post.date.formatted(.dateTime.month(.abbreviated).day()))
                    }
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.neueCaption2Medium)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(12)
        }
    }

    private var ourDesignsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Our Designs")
                    .font(.neueCorpMedium(24))
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
                Button {
                    showDesignDirectory = true
                } label: {
                    Text("See All")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(viewModel.allHomeDesigns.prefix(6)) { design in
                        NavigationLink(value: design) {
                            designCard(design: design)
                        }
                    }

                    Button {
                        showDesignDirectory = true
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.neueCorpMedium(28))
                                .foregroundStyle(AVIATheme.timelessBrown)
                            Text("View All\n\(viewModel.allHomeDesigns.count) Designs")
                                .font(.neueCaptionMedium)
                                .foregroundStyle(AVIATheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: 260, height: 325)
                        .background(AVIATheme.cardBackground)
                        .clipShape(.rect(cornerRadius: 16))
                    }
                }
            }
            .contentMargins(.horizontal, 0)
            .scrollIndicators(.hidden)
        }
    }

    private func designCard(design: HomeDesign) -> some View {
        Color(AVIATheme.surfaceElevated)
            .frame(width: 260, height: 325)
            .overlay {
                AsyncImage(url: URL(string: design.imageURL)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else if phase.error != nil {
                        Image(systemName: "house.fill")
                            .font(.neueCorpMedium(24))
                            .foregroundStyle(AVIATheme.timelessBrown.opacity(0.25))
                    } else {
                        ProgressView()
                    }
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                if design.storeys == 2 {
                    AVIAChip("2 STOREY", onLight: false)
                        .padding(8)
                }
            }
            .overlay(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(design.name)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)

                    Text("\(design.bedrooms) Bed · \(design.bathrooms) Bath · \(design.garages) Car · \(String(format: "%.0fm²", design.squareMeters))")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial)
                .clipShape(.rect(cornerRadii: .init(bottomLeading: 16, bottomTrailing: 16)))
            }
            .clipShape(.rect(cornerRadius: 16))
    }

    private var houseLandSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "House & Land", icon: "map.fill")

            ForEach(viewModel.allPackages.prefix(5)) { pkg in
                houseLandCard(package: pkg)
            }
        }
    }

    private func houseLandCard(package: HouseLandPackage) -> some View {
        BentoCard(cornerRadius: 16) {
            HStack(spacing: 12) {
                Color(AVIATheme.surfaceElevated)
                    .frame(width: 90, height: 90)
                    .overlay {
                        AsyncImage(url: URL(string: package.imageURL)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(alignment: .topLeading) {
                        if package.isNew {
                            AVIAChip("NEW", onLight: false)
                                .padding(4)
                        }
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(package.title)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.neueCorp(10))
                            .foregroundStyle(AVIATheme.timelessBrown)
                        Text(package.location)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 12) {
                        Label(package.lotSize, systemImage: "ruler")
                        Label(package.homeDesign, systemImage: "house")
                    }
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .lineLimit(1)

                    Text(package.price)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.timelessBrown)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }

    private var companyHighlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Why AVIA")
                    .font(.neueCorpMedium(24))
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
            }

            HStack(spacing: 12) {
                highlightCard(icon: "shield.checkerboard", title: "Quality\nAssured", description: "HIA member with full structural warranty")
                highlightCard(icon: "person.2.fill", title: "Personal\nService", description: "Dedicated build coordinator for your project")
            }
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                highlightCard(icon: "leaf.fill", title: "Sustainable\nDesign", description: "Energy efficient homes as standard")
                highlightCard(icon: "star.fill", title: "Award\nWinning", description: "Multi-award winning Queensland builder")
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func highlightCard(icon: String, title: String, description: String) -> some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .lineLimit(2)
                Text(description)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var contactBanner: some View {
        VStack(spacing: 0) {
            Color(AVIATheme.timelessBrown)
                .frame(height: 140)
                .overlay {
                    AsyncImage(url: URL(string: "https://pub-e001eb4506b145aa938b5d3badbff6a5.r2.dev/attachments/t8j7r8vibjqzvubxzcnbg.jpeg")) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill).opacity(0.3)
                        }
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))
                .overlay {
                    VStack(spacing: 8) {
                        Image("AVIALogo")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 22)
                            .foregroundStyle(AVIATheme.aviaWhite)

                        Text("We Build Homes Worth Living In")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.aviaWhite.opacity(0.7))
                    }
                }

            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    if let phoneURL = URL(string: "tel:0756545123") {
                        Link(destination: phoneURL) {
                            HStack(spacing: 6) {
                                Image(systemName: "phone.fill").font(.neueCaption2)
                                Text("Call Us").font(.neueCaptionMedium)
                            }
                            .foregroundStyle(AVIATheme.aviaWhite)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(AVIATheme.brownGradient)
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }

                    if let webURL = URL(string: "https://www.aviahomes.com.au") {
                        Link(destination: webURL) {
                            HStack(spacing: 6) {
                                Image(systemName: "safari.fill").font(.neueCaption2)
                                Text("Website").font(.neueCaptionMedium)
                            }
                            .foregroundStyle(AVIATheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(AVIATheme.surfaceElevated)
                            .clipShape(.rect(cornerRadius: 10))
                        }
                    }
                }

                HStack(spacing: 16) {
                    Label("Queensland", systemImage: "mappin.and.ellipse")
                    Spacer()
                    Label("Mon–Fri 8am–4pm", systemImage: "clock")
                }
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(14)
        }
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.neueCorpMedium(20))
                .foregroundStyle(AVIATheme.textPrimary)
            Spacer()
        }
    }
}

struct GaugeArc: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height * 2)
            let lineWidth: CGFloat = 10

            ZStack {
                ArcShape()
                    .stroke(color.opacity(0.12), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: size, height: size / 2)

                ArcShape()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .frame(width: size, height: size / 2)

                VStack(spacing: 0) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(Int(progress * 100))")
                            .font(.neueCorpMedium(28))
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("%")
                            .font(.neueCorpMedium(14))
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                }
                .offset(y: size * 0.1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

struct ArcShape: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width, rect.height * 2) / 2
        path.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        return path
    }
}

struct ResourceMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.neueCorpMedium(22))
                .foregroundStyle(AVIATheme.textPrimary)
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SegmentedProgressBar: View {
    let progress: Double
    private let totalSegments = 20

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 2
            let segmentWidth = (geo.size.width - CGFloat(totalSegments - 1) * spacing) / CGFloat(totalSegments)
            let filledCount = Int(progress * Double(totalSegments))

            HStack(spacing: spacing) {
                ForEach(0..<totalSegments, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index < filledCount ? AVIATheme.timelessBrown : AVIATheme.surfaceBorder)
                        .frame(width: segmentWidth)
                }
            }
        }
    }
}
