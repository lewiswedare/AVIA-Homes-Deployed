import SwiftUI

struct PackagesContentView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var selectedEstate: String? = nil
    @State private var selectedStatus: PackageStatus? = nil

    private var basePackages: [HouseLandPackage] {
        viewModel.packagesForCurrentUser()
    }

    private var availableEstates: [String] {
        let estates = Set(basePackages.map(\.estate))
        return estates.sorted()
    }

    private var filteredPackages: [HouseLandPackage] {
        var packages = basePackages

        if let estate = selectedEstate {
            packages = packages.filter { $0.estate == estate }
        }

        if let status = selectedStatus {
            packages = packages.filter { $0.status == status }
        }

        return packages
    }

    private var availableCount: Int {
        basePackages.filter { $0.status == .available }.count
    }

    var body: some View {
        VStack(spacing: 16) {
            summaryCards
            filterSection
            packageCount
            packagesList
        }
    }

    private var summaryCards: some View {
        HStack(spacing: 12) {
            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    BentoIconCircle(icon: "house.and.flag.fill", color: AVIATheme.teal)
                    Text("\(basePackages.count)")
                        .font(.neueCorpMedium(32))
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Total Packages")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            BentoCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    BentoIconCircle(icon: "checkmark.circle.fill", color: AVIATheme.success)
                    Text("\(availableCount)")
                        .font(.neueCorpMedium(32))
                        .foregroundStyle(AVIATheme.textPrimary)
                    Text("Available Now")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var filterSection: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Menu {
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedEstate = nil }
                    } label: {
                        HStack {
                            Text("All Estates")
                            if selectedEstate == nil { Image(systemName: "checkmark") }
                        }
                    }
                    ForEach(availableEstates, id: \.self) { estate in
                        Button {
                            withAnimation(.spring(response: 0.3)) { selectedEstate = estate }
                        } label: {
                            HStack {
                                Text(estate)
                                if selectedEstate == estate { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "map.fill")
                            .font(.neueCorp(10))
                        Text(selectedEstate ?? "All Estates")
                            .font(.neueCaptionMedium)
                    }
                    .foregroundStyle(selectedEstate != nil ? .white : AVIATheme.textPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(selectedEstate != nil ? AVIATheme.teal : AVIATheme.cardBackground)
                    .clipShape(Capsule())
                    .overlay {
                        if selectedEstate == nil {
                            Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                        }
                    }
                }

                ForEach([PackageStatus.available, .underOffer], id: \.self) { status in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedStatus = selectedStatus == status ? nil : status
                        }
                    } label: {
                        Text(status.rawValue)
                            .font(.neueCaptionMedium)
                            .foregroundStyle(selectedStatus == status ? .white : AVIATheme.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(selectedStatus == status ? AVIATheme.teal : AVIATheme.cardBackground)
                            .clipShape(Capsule())
                            .overlay {
                                if selectedStatus != status {
                                    Capsule().stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                                }
                            }
                    }
                    .sensoryFeedback(.selection, trigger: selectedStatus)
                }

                if selectedEstate != nil || selectedStatus != nil {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedEstate = nil
                            selectedStatus = nil
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark")
                                .font(.neueCorp(9))
                            Text("Clear")
                                .font(.neueCaptionMedium)
                        }
                        .foregroundStyle(AVIATheme.destructive)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .contentMargins(.horizontal, 0)
        .scrollIndicators(.hidden)
    }

    private var packageCount: some View {
        HStack {
            Text("\(filteredPackages.count) package\(filteredPackages.count == 1 ? "" : "s")")
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textTertiary)
            Spacer()
        }
    }

    private var packagesList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredPackages) { pkg in
                NavigationLink(value: pkg) {
                    packageCard(package: pkg)
                }
            }
        }
    }

    private func packageCard(package: HouseLandPackage) -> some View {
        BentoCard(cornerRadius: 16) {
            VStack(spacing: 0) {
                Color(AVIATheme.surfaceElevated)
                    .frame(height: 160)
                    .overlay {
                        AsyncImage(url: URL(string: package.imageURL)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 6) {
                            if package.isNew {
                                Text("NEW")
                                    .font(.neueCorpMedium(8))
                                    .kerning(0.5)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AVIATheme.teal)
                                    .clipShape(Capsule())
                            }
                            statusBadge(package.status)
                        }
                        .padding(10)
                    }
                    .clipShape(.rect(cornerRadii: .init(topLeading: 16, topTrailing: 16)))

                VStack(alignment: .leading, spacing: 8) {
                    Text(package.title)
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.neueCorp(10))
                            .foregroundStyle(AVIATheme.teal)
                        Text(package.location)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 14) {
                        Label("\(package.bedrooms)", systemImage: "bed.double.fill")
                        Label("\(package.bathrooms)", systemImage: "shower.fill")
                        Label("\(package.garages)", systemImage: "car.fill")
                        Label(package.lotSize, systemImage: "ruler")
                    }
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)

                    HStack {
                        Text(package.price)
                            .font(.neueCorpMedium(18))
                            .foregroundStyle(AVIATheme.teal)
                        Spacer()
                        Text(package.homeDesign)
                            .font(.neueCaption2Medium)
                            .foregroundStyle(AVIATheme.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AVIATheme.surfaceElevated)
                            .clipShape(Capsule())
                    }
                }
                .padding(14)
            }
        }
    }

    private func statusBadge(_ status: PackageStatus) -> some View {
        Text(status.rawValue)
            .font(.neueCorpMedium(8))
            .kerning(0.4)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor(status))
            .clipShape(Capsule())
    }

    private func statusColor(_ status: PackageStatus) -> Color {
        switch status {
        case .available: return AVIATheme.success
        case .underOffer: return AVIATheme.warning
        case .sold: return AVIATheme.destructive
        }
    }
}
