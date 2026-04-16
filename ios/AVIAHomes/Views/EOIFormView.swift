import SwiftUI

struct EOIFormView: View {
    let package: HouseLandPackage
    let assignment: PackageAssignment
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0
    @State private var isSubmitting = false
    @State private var showValidationError = false
    @State private var validationMessage = ""

    // Step 1 — Property Details
    @State private var streetSuburb = ""
    @State private var occupancyType = "owner_occupier"

    // Step 2 — Buyer Details
    @State private var buyer1Name = ""
    @State private var buyer1Email = ""
    @State private var buyer1Address = ""
    @State private var buyer1Phone = ""
    @State private var hasSecondBuyer = false
    @State private var buyer2Name = ""
    @State private var buyer2Email = ""
    @State private var buyer2Address = ""
    @State private var buyer2Phone = ""

    // Step 3 — Solicitor Details
    @State private var solicitorCompany = ""
    @State private var solicitorName = ""
    @State private var solicitorEmail = ""
    @State private var solicitorAddress = ""
    @State private var solicitorPhone = ""

    private let stepTitles = ["Property", "Buyers", "Solicitor", "Review"]
    private let occupancyOptions = ["investor", "owner_occupier", "corporate"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                ScrollView {
                    VStack(spacing: 20) {
                        switch currentStep {
                        case 0: propertyStep
                        case 1: buyerStep
                        case 2: solicitorStep
                        case 3: reviewStep
                        default: EmptyView()
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 80)
                }
                navigationButtons
            }
            .background(AVIATheme.background)
            .navigationTitle("Expression of Interest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.neueSubheadline)
                }
            }
            .alert("Missing Information", isPresented: $showValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
            .onAppear { prefillFromProfile() }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(0..<4) { step in
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(step <= currentStep ? AVIATheme.timelessBrown : AVIATheme.surfaceBorder)
                            .frame(width: 28, height: 28)
                        if step < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(step + 1)")
                                .font(.neueCaption2Medium)
                                .foregroundStyle(step <= currentStep ? .white : AVIATheme.textTertiary)
                        }
                    }
                    Text(stepTitles[step])
                        .font(.neueCaption2)
                        .foregroundStyle(step <= currentStep ? AVIATheme.textPrimary : AVIATheme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                if step < 3 {
                    Rectangle()
                        .fill(step < currentStep ? AVIATheme.timelessBrown : AVIATheme.surfaceBorder)
                        .frame(height: 2)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 18)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(AVIATheme.cardBackground)
    }

    // MARK: - Step 1: Property

    private var propertyStep: some View {
        VStack(spacing: 16) {
            sectionHeader("Property Details", icon: "house.fill")

            readOnlyField("Lot Number", value: package.lotNumber)
            readOnlyField("Estate", value: package.location)
            formTextField("Street & Suburb", text: $streetSuburb)

            VStack(alignment: .leading, spacing: 8) {
                Text("Occupancy Type")
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textSecondary)
                Picker("Occupancy", selection: $occupancyType) {
                    Text("Investor").tag("investor")
                    Text("Owner Occupier").tag("owner_occupier")
                    Text("Corporate").tag("corporate")
                }
                .pickerStyle(.segmented)
            }

            readOnlyField("Specification Tier", value: package.specTier.displayName)
            if let facadeId = package.selectedFacadeId {
                readOnlyField("Facade", value: facadeId)
            }
        }
    }

    // MARK: - Step 2: Buyers

    private var buyerStep: some View {
        VStack(spacing: 16) {
            sectionHeader("Buyer One", icon: "person.fill")

            formTextField("Full Name", text: $buyer1Name)
            formTextField("Email", text: $buyer1Email, keyboard: .emailAddress)
            formTextField("Address", text: $buyer1Address)
            formTextField("Phone", text: $buyer1Phone, keyboard: .phonePad)

            Divider().padding(.vertical, 4)

            Toggle(isOn: $hasSecondBuyer) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.timelessBrown)
                    Text("Add Second Buyer")
                        .font(.neueSubheadlineMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                }
            }
            .tint(AVIATheme.timelessBrown)

            if hasSecondBuyer {
                sectionHeader("Buyer Two", icon: "person.fill")
                formTextField("Full Name", text: $buyer2Name)
                formTextField("Email", text: $buyer2Email, keyboard: .emailAddress)
                formTextField("Address", text: $buyer2Address)
                formTextField("Phone", text: $buyer2Phone, keyboard: .phonePad)
            }
        }
    }

    // MARK: - Step 3: Solicitor

    private var solicitorStep: some View {
        VStack(spacing: 16) {
            sectionHeader("Solicitor Details", icon: "building.columns.fill")

            formTextField("Company", text: $solicitorCompany)
            formTextField("Contact Name", text: $solicitorName)
            formTextField("Email", text: $solicitorEmail, keyboard: .emailAddress)
            formTextField("Address", text: $solicitorAddress)
            formTextField("Phone", text: $solicitorPhone, keyboard: .phonePad)
        }
    }

    // MARK: - Step 4: Review

    private var reviewStep: some View {
        VStack(spacing: 16) {
            sectionHeader("Review Your EOI", icon: "doc.text.magnifyingglass")

            BentoCard(cornerRadius: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    reviewSectionTitle("Property")
                    reviewRow("Lot", package.lotNumber)
                    reviewRow("Estate", package.location)
                    if !streetSuburb.isEmpty {
                        reviewRow("Street & Suburb", streetSuburb)
                    }
                    reviewRow("Occupancy", occupancyLabel)
                    reviewRow("Spec Tier", package.specTier.displayName)
                }
                .padding(16)
            }

            BentoCard(cornerRadius: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    reviewSectionTitle("Buyer One")
                    reviewRow("Name", buyer1Name)
                    reviewRow("Email", buyer1Email)
                    reviewRow("Address", buyer1Address)
                    reviewRow("Phone", buyer1Phone)

                    if hasSecondBuyer {
                        Divider().padding(.vertical, 4)
                        reviewSectionTitle("Buyer Two")
                        reviewRow("Name", buyer2Name)
                        reviewRow("Email", buyer2Email)
                        reviewRow("Address", buyer2Address)
                        reviewRow("Phone", buyer2Phone)
                    }
                }
                .padding(16)
            }

            BentoCard(cornerRadius: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    reviewSectionTitle("Solicitor")
                    reviewRow("Company", solicitorCompany)
                    reviewRow("Name", solicitorName)
                    reviewRow("Email", solicitorEmail)
                    reviewRow("Address", solicitorAddress)
                    reviewRow("Phone", solicitorPhone)
                }
                .padding(16)
            }

            BentoCard(cornerRadius: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    reviewSectionTitle("Deposit Payment Details")
                    Text("Please transfer the deposit to:")
                        .font(.neueCaption)
                        .foregroundStyle(AVIATheme.textSecondary)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AVIA HOMES PTY LTD")
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        reviewRow("BSB", "064-474")
                        reviewRow("Account", "1087 5601")
                        reviewRow("Reference", "\(package.lotNumber) \(buyerLastName)")
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentStep > 0 {
                Button {
                    withAnimation(.spring(response: 0.3)) { currentStep -= 1 }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.neueCaption2Medium)
                        Text("Back")
                            .font(.neueSubheadlineMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(AVIATheme.timelessBrown)
                    .background(AVIATheme.timelessBrown.opacity(0.1))
                    .clipShape(.rect(cornerRadius: 14))
                }
            }

            if currentStep < 3 {
                Button {
                    if validateCurrentStep() {
                        withAnimation(.spring(response: 0.3)) { currentStep += 1 }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Next")
                            .font(.neueSubheadlineMedium)
                        Image(systemName: "chevron.right")
                            .font(.neueCaption2Medium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.white)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 14))
                }
            } else {
                Button {
                    Task { await submitEOI() }
                } label: {
                    HStack(spacing: 8) {
                        if isSubmitting {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.neueSubheadlineMedium)
                        }
                        Text("Submit EOI")
                            .font(.neueSubheadlineMedium)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.white)
                    .background(AVIATheme.primaryGradient)
                    .clipShape(.rect(cornerRadius: 14))
                }
                .disabled(isSubmitting)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AVIATheme.cardBackground)
    }

    // MARK: - Helpers

    private func prefillFromProfile() {
        let user = viewModel.currentUser
        buyer1Name = user.fullName
        buyer1Email = user.email
        buyer1Phone = user.phone
    }

    private var occupancyLabel: String {
        switch occupancyType {
        case "investor": return "Investor"
        case "owner_occupier": return "Owner Occupier"
        case "corporate": return "Corporate"
        default: return occupancyType
        }
    }

    private var buyerLastName: String {
        buyer1Name.split(separator: " ").last.map(String.init) ?? buyer1Name
    }

    private func validateCurrentStep() -> Bool {
        switch currentStep {
        case 0:
            return true
        case 1:
            guard !buyer1Name.isEmpty, !buyer1Email.isEmpty, !buyer1Address.isEmpty, !buyer1Phone.isEmpty else {
                validationMessage = "Please fill in all Buyer One fields."
                showValidationError = true
                return false
            }
            if hasSecondBuyer {
                guard !buyer2Name.isEmpty, !buyer2Email.isEmpty, !buyer2Address.isEmpty, !buyer2Phone.isEmpty else {
                    validationMessage = "Please fill in all Buyer Two fields."
                    showValidationError = true
                    return false
                }
            }
            return true
        case 2:
            guard !solicitorCompany.isEmpty, !solicitorName.isEmpty, !solicitorEmail.isEmpty, !solicitorAddress.isEmpty, !solicitorPhone.isEmpty else {
                validationMessage = "Please fill in all solicitor fields."
                showValidationError = true
                return false
            }
            return true
        default:
            return true
        }
    }

    private func submitEOI() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let row = EOISubmissionRow(
            id: UUID().uuidString,
            package_assignment_id: assignment.id,
            package_id: package.id,
            client_id: viewModel.currentUser.id,
            lot_number: package.lotNumber,
            estate_name: package.location,
            street_suburb: streetSuburb.isEmpty ? nil : streetSuburb,
            occupancy_type: occupancyType,
            specification_tier: package.specTier.displayName,
            facade_selection: package.selectedFacadeId,
            buyer1_name: buyer1Name,
            buyer1_email: buyer1Email,
            buyer1_address: buyer1Address,
            buyer1_phone: buyer1Phone,
            buyer2_name: hasSecondBuyer ? buyer2Name : nil,
            buyer2_email: hasSecondBuyer ? buyer2Email : nil,
            buyer2_address: hasSecondBuyer ? buyer2Address : nil,
            buyer2_phone: hasSecondBuyer ? buyer2Phone : nil,
            solicitor_company: solicitorCompany,
            solicitor_name: solicitorName,
            solicitor_email: solicitorEmail,
            solicitor_address: solicitorAddress,
            solicitor_phone: solicitorPhone,
            status: "submitted",
            admin_notes: nil,
            reviewed_by: nil,
            reviewed_at: nil,
            created_at: nil,
            updated_at: nil
        )

        let success = await SupabaseService.shared.submitEOI(row)
        guard success else { return }

        viewModel.respondToPackage(packageId: package.id, status: .accepted)

        // Notify admins/staff
        let packageTitle = package.title
        var recipientIdSet = Set<String>()
        for user in viewModel.allRegisteredUsers where user.role.isAnyStaffRole {
            recipientIdSet.insert(user.id)
        }
        for user in viewModel.allRegisteredUsers where user.role == .admin {
            recipientIdSet.insert(user.id)
        }
        recipientIdSet.remove(viewModel.currentUser.id)
        for recipientId in recipientIdSet {
            await viewModel.notificationService.createNotification(
                recipientId: recipientId,
                senderId: viewModel.currentUser.id,
                senderName: viewModel.currentUser.fullName,
                type: .eoiSubmitted,
                title: "EOI Submitted",
                message: "\(viewModel.currentUser.fullName) submitted an EOI for \(packageTitle)",
                referenceId: package.id,
                referenceType: "package"
            )
        }

        dismiss()
    }

    // MARK: - Reusable Components

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.timelessBrown)
            Text(title)
                .font(.neueCorpMedium(18))
                .foregroundStyle(AVIATheme.textPrimary)
            Spacer()
        }
        .padding(.bottom, 4)
    }

    private func readOnlyField(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textSecondary)
            Text(value.isEmpty ? "—" : value)
                .font(.neueSubheadline)
                .foregroundStyle(AVIATheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(AVIATheme.surfaceElevated.opacity(0.5))
                .clipShape(.rect(cornerRadius: 10))
        }
    }

    private func formTextField(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textSecondary)
            TextField(label, text: text)
                .font(.neueSubheadline)
                .keyboardType(keyboard)
                .textContentType(contentType(for: label))
                .autocorrectionDisabled()
                .padding(12)
                .background(AVIATheme.cardBackground)
                .clipShape(.rect(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                }
        }
    }

    private func contentType(for label: String) -> UITextContentType? {
        let lower = label.lowercased()
        if lower.contains("email") { return .emailAddress }
        if lower.contains("phone") { return .telephoneNumber }
        if lower.contains("name") { return .name }
        if lower.contains("address") { return .fullStreetAddress }
        return nil
    }

    private func reviewSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.neueSubheadlineMedium)
            .foregroundStyle(AVIATheme.timelessBrown)
    }

    private func reviewRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textPrimary)
        }
    }
}
