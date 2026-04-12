import SwiftUI

struct AddBuildSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var homeDesign = ""
    @State private var lotNumber = ""
    @State private var estate = ""
    @State private var contractDate = Date.now
    @State private var selectedClientId = ""
    @State private var selectedStaffId = ""
    @State private var isSaving = false
    @State private var isCustomHome = false
    @State private var customDesignName = ""
    @State private var customBedrooms = 4
    @State private var customBathrooms = 2
    @State private var customGarages = 2
    @State private var customSquareMeters = ""
    @State private var customStoreys = 1
    @State private var selectedFacadeId = ""
    @State private var selectedDesignId = ""
    @State private var selectedSpecTier: SpecTier = .messina

    private var designs: [HomeDesign] {
        let d = viewModel.allHomeDesigns
        return d
    }

    private var facades: [Facade] {
        let f = viewModel.allFacades
        return f
    }

    private var selectedDesign: HomeDesign? {
        designs.first { $0.id == selectedDesignId }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    buildTypeToggle

                    if isCustomHome {
                        customDesignCard
                    } else {
                        standardDesignCard
                    }

                    buildDetailsCard

                    specTierCard

                    if isCustomHome {
                        facadeCard
                    }

                    clientCard
                    staffCard

                    Button(action: createBuild) {
                        Group {
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Create Build")
                                }
                                .font(.neueSubheadlineMedium)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(isFormValid ? AVIATheme.tealGradient : LinearGradient(colors: [AVIATheme.textTertiary], startPoint: .leading, endPoint: .trailing))
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .disabled(!isFormValid || isSaving)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("New Build")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(AVIATheme.teal)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AVIATheme.background)
    }

    private var isFormValid: Bool {
        let hasDesign = isCustomHome ? !customDesignName.trimmingCharacters(in: .whitespaces).isEmpty : !selectedDesignId.isEmpty
        return hasDesign &&
        !lotNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        !estate.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var buildTypeToggle: some View {
        HStack(spacing: 12) {
            Toggle(isOn: $isCustomHome) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.and.ruler.fill")
                        .font(.neueCorp(12))
                        .foregroundStyle(AVIATheme.teal)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Custom Home")
                            .font(.neueCaptionMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        Text("Client has their own design")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textTertiary)
                    }
                }
            }
            .tint(AVIATheme.teal)
        }
        .padding(16)
        .background(isCustomHome ? AVIATheme.teal.opacity(0.06) : AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 16))
        .sensoryFeedback(.impact(weight: .light), trigger: isCustomHome)
    }

    private var standardDesignCard: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Select Design", systemImage: "house.fill")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)

                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(designs) { design in
                            let isSelected = selectedDesignId == design.id
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedDesignId = design.id
                                    homeDesign = "\(design.name) \(Int(design.squareMeters))"
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Color(AVIATheme.surfaceElevated)
                                        .frame(width: 44, height: 44)
                                        .overlay {
                                            AsyncImage(url: URL(string: design.imageURL)) { phase in
                                                if let image = phase.image {
                                                    image.resizable().aspectRatio(contentMode: .fill)
                                                }
                                            }
                                            .allowsHitTesting(false)
                                        }
                                        .clipShape(.rect(cornerRadius: 8))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(design.name)
                                            .font(.neueCaptionMedium)
                                            .foregroundStyle(AVIATheme.textPrimary)
                                        HStack(spacing: 6) {
                                            Label("\(design.bedrooms)", systemImage: "bed.double.fill")
                                            Label("\(design.bathrooms)", systemImage: "shower.fill")
                                            Label("\(design.garages)", systemImage: "car.fill")
                                            Text("\u{2022}")
                                            Text(String(format: "%.0fm\u{00b2}", design.squareMeters))
                                        }
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                    }

                                    Spacer()

                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(isSelected ? AVIATheme.teal : AVIATheme.surfaceBorder)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isSelected ? AVIATheme.teal.opacity(0.06) : Color.clear)
                                .clipShape(.rect(cornerRadius: 10))
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            .padding(16)
        }
    }

    private var customDesignCard: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.and.ruler.fill")
                        .foregroundStyle(AVIATheme.teal)
                    Text("Custom Design Details")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    Spacer()
                    Text("CUSTOM")
                        .font(.neueCorpMedium(8))
                        .kerning(0.4)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AVIATheme.teal)
                        .clipShape(Capsule())
                }

                fieldRow(label: "Design Name", text: $customDesignName, placeholder: "e.g. Smith Family Residence", icon: "pencil.line")
                fieldRow(label: "Square Metres", text: $customSquareMeters, placeholder: "e.g. 280", icon: "square.dashed")

                VStack(spacing: 10) {
                    stepperRow(icon: "bed.double.fill", label: "Bedrooms", value: $customBedrooms, range: 1...8)
                    stepperRow(icon: "shower.fill", label: "Bathrooms", value: $customBathrooms, range: 1...6)
                    stepperRow(icon: "car.fill", label: "Garages", value: $customGarages, range: 0...4)
                    stepperRow(icon: "arrow.up.arrow.down", label: "Storeys", value: $customStoreys, range: 1...3)
                }
            }
            .padding(16)
        }
    }

    private var buildDetailsCard: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Build Details", systemImage: "mappin.and.ellipse")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)

                fieldRow(label: "Lot Number", text: $lotNumber, placeholder: "e.g. Lot 42", icon: "number")
                fieldRow(label: "Estate", text: $estate, placeholder: "e.g. Harmony Estate, Palmview", icon: "mappin.circle.fill")

                VStack(alignment: .leading, spacing: 6) {
                    Label("Contract Date", systemImage: "calendar")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textTertiary)
                    DatePicker("", selection: $contractDate, displayedComponents: .date)
                        .labelsHidden()
                        .tint(AVIATheme.teal)
                }
            }
            .padding(16)
        }
    }

    private var specTierCard: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("SPECIFICATION RANGE")
                    .font(.neueCaption2Medium)
                    .kerning(1.0)
                    .foregroundStyle(AVIATheme.textTertiary)

                HStack(spacing: 8) {
                    ForEach(SpecTier.allCases) { tier in
                        let isSelected = selectedSpecTier == tier
                        Button {
                            withAnimation(.spring(response: 0.3)) { selectedSpecTier = tier }
                        } label: {
                            VStack(spacing: 4) {
                                Text(tier.rawValue)
                                    .font(.neueCaptionMedium)
                                Text(tier.tagline)
                                    .font(.neueCaption2)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(isSelected ? .white : AVIATheme.textPrimary)
                            .background(isSelected ? AVIATheme.tealGradient : LinearGradient(colors: [AVIATheme.surfaceElevated], startPoint: .top, endPoint: .bottom))
                            .clipShape(.rect(cornerRadius: 12))
                        }
                        .sensoryFeedback(.selection, trigger: selectedSpecTier)
                    }
                }
            }
            .padding(16)
        }
    }

    private var facadeCard: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("SELECT FACADE")
                        .font(.neueCaption2Medium)
                        .kerning(1.0)
                        .foregroundStyle(AVIATheme.textTertiary)
                    Spacer()
                    if !selectedFacadeId.isEmpty {
                        Button {
                            withAnimation { selectedFacadeId = "" }
                        } label: {
                            Text("Clear")
                                .font(.neueCaption2Medium)
                                .foregroundStyle(AVIATheme.destructive)
                        }
                    }
                }

                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(facades) { facade in
                            let isSelected = selectedFacadeId == facade.id
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedFacadeId = facade.id
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Color(AVIATheme.surfaceElevated)
                                        .frame(width: 44, height: 44)
                                        .overlay {
                                            AsyncImage(url: URL(string: facade.heroImageURL)) { phase in
                                                if let image = phase.image {
                                                    image.resizable().aspectRatio(contentMode: .fill)
                                                }
                                            }
                                            .allowsHitTesting(false)
                                        }
                                        .clipShape(.rect(cornerRadius: 8))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(facade.name)
                                            .font(.neueCaptionMedium)
                                            .foregroundStyle(AVIATheme.textPrimary)
                                        Text(facade.style)
                                            .font(.neueCaption2)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    }

                                    Spacer()

                                    Text(facade.pricing.displayText)
                                        .font(.neueCaption2)
                                        .foregroundStyle(facade.pricing.isIncluded ? AVIATheme.success : AVIATheme.textSecondary)

                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(isSelected ? AVIATheme.teal : AVIATheme.surfaceBorder)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isSelected ? AVIATheme.teal.opacity(0.06) : Color.clear)
                                .clipShape(.rect(cornerRadius: 10))
                            }
                            .sensoryFeedback(.selection, trigger: selectedFacadeId)
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
            .padding(16)
        }
    }

    private var clientCard: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Assign Client", systemImage: "person.fill")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)

                let clients = viewModel.clientUsers
                if clients.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text("No clients registered yet")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    VStack(spacing: 6) {
                        ForEach(clients, id: \.id) { client in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedClientId = client.id
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Text(client.initials.isEmpty ? "?" : client.initials)
                                        .font(.neueCorp(10))
                                        .foregroundStyle(.white)
                                        .frame(width: 30, height: 30)
                                        .background(AVIATheme.tealGradient)
                                        .clipShape(Circle())

                                    Text(client.fullName.trimmingCharacters(in: .whitespaces).isEmpty ? client.email : client.fullName)
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(AVIATheme.textPrimary)
                                        .lineLimit(1)

                                    Spacer()

                                    Image(systemName: selectedClientId == client.id ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(selectedClientId == client.id ? AVIATheme.teal : AVIATheme.surfaceBorder)
                                }
                                .padding(10)
                                .background(selectedClientId == client.id ? AVIATheme.teal.opacity(0.06) : Color.clear)
                                .clipShape(.rect(cornerRadius: 10))
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private var staffCard: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Assign Staff", systemImage: "person.badge.shield.checkmark.fill")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)

                let staff = viewModel.staffUsers
                if staff.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(AVIATheme.textTertiary)
                        Text("No staff members available")
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    VStack(spacing: 6) {
                        ForEach(staff, id: \.id) { member in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedStaffId = member.id
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Text(member.initials)
                                        .font(.neueCorp(10))
                                        .foregroundStyle(.white)
                                        .frame(width: 30, height: 30)
                                        .background(AVIATheme.tealGradient)
                                        .clipShape(Circle())

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(member.fullName)
                                            .font(.neueCaptionMedium)
                                            .foregroundStyle(AVIATheme.textPrimary)
                                        Text(member.role.rawValue)
                                            .font(.neueCaption2)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                    }

                                    Spacer()

                                    Image(systemName: selectedStaffId == member.id ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                        .foregroundStyle(selectedStaffId == member.id ? AVIATheme.teal : AVIATheme.surfaceBorder)
                                }
                                .padding(10)
                                .background(selectedStaffId == member.id ? AVIATheme.teal.opacity(0.06) : Color.clear)
                                .clipShape(.rect(cornerRadius: 10))
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func fieldRow(label: String, text: Binding<String>, placeholder: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
            TextField(placeholder, text: text)
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textPrimary)
                .padding(12)
                .background(AVIATheme.cardBackgroundAlt)
                .clipShape(.rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                }
        }
    }

    private func stepperRow(icon: String, label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.neueCorp(12))
                .foregroundStyle(AVIATheme.teal)
                .frame(width: 24)
            Text(label)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textPrimary)
            Spacer()
            HStack(spacing: 14) {
                Button {
                    if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(value.wrappedValue > range.lowerBound ? AVIATheme.teal : AVIATheme.surfaceBorder)
                }
                .disabled(value.wrappedValue <= range.lowerBound)

                Text("\(value.wrappedValue)")
                    .font(.neueSubheadlineMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                    .frame(width: 20)

                Button {
                    if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(value.wrappedValue < range.upperBound ? AVIATheme.teal : AVIATheme.surfaceBorder)
                }
                .disabled(value.wrappedValue >= range.upperBound)
            }
        }
    }

    private func createBuild() {
        isSaving = true
        Task {
            try? await Task.sleep(for: .seconds(0.8))

            let designName: String
            if isCustomHome {
                designName = customDesignName.trimmingCharacters(in: .whitespaces)
            } else if let design = selectedDesign {
                designName = "\(design.name) \(Int(design.squareMeters))"
            } else {
                designName = homeDesign
            }

            viewModel.addNewBuildWithSpec(
                homeDesign: designName,
                lotNumber: lotNumber,
                estate: estate,
                contractDate: contractDate,
                clientId: selectedClientId,
                staffId: selectedStaffId,
                specTier: selectedSpecTier,
                isCustom: isCustomHome,
                selectedFacadeId: isCustomHome && !selectedFacadeId.isEmpty ? selectedFacadeId : nil,
                customBedrooms: isCustomHome ? customBedrooms : nil,
                customBathrooms: isCustomHome ? customBathrooms : nil,
                customGarages: isCustomHome ? customGarages : nil,
                customSquareMeters: isCustomHome ? Double(customSquareMeters) : nil,
                customStoreys: isCustomHome ? customStoreys : nil
            )
            isSaving = false
            dismiss()
        }
    }
}
