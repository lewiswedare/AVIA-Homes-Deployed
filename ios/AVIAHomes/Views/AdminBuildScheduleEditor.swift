import SwiftUI

struct AdminBuildScheduleEditor: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    let build: ClientBuild

    @State private var estStart: Date?
    @State private var estCompletion: Date?
    @State private var actualStart: Date?
    @State private var actualCompletion: Date?
    @State private var hasEstStart = false
    @State private var hasEstCompletion = false
    @State private var hasActualStart = false
    @State private var hasActualCompletion = false
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BentoCard(cornerRadius: 13) {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Build Schedule", systemImage: "calendar.badge.clock")
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)
                            Text("These dates appear on the client's Build Progress timeline.")
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)

                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                            row(label: "Estimated Start", icon: "play.circle.fill", color: AVIATheme.timelessBrown, hasValue: $hasEstStart, value: $estStart)
                            row(label: "Estimated Completion", icon: "flag.checkered", color: AVIATheme.success, hasValue: $hasEstCompletion, value: $estCompletion)

                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                            row(label: "Actual Start", icon: "hammer.fill", color: AVIATheme.warning, hasValue: $hasActualStart, value: $actualStart)
                            row(label: "Actual Completion", icon: "checkmark.seal.fill", color: AVIATheme.success, hasValue: $hasActualCompletion, value: $actualCompletion)
                        }
                        .padding(16)
                    }

                    if let saveError {
                        Text(saveError)
                            .font(.neueCaption)
                            .foregroundStyle(AVIATheme.destructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(AVIATheme.destructive.opacity(0.08))
                            .clipShape(.rect(cornerRadius: 10))
                    }

                    PremiumButton(isSaving ? "Saving…" : "Save Schedule", icon: "checkmark", style: .primary) {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(AVIATheme.background)
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(AVIATheme.timelessBrown)
                }
            }
        }
        .onAppear {
            estStart = build.estimatedStartDate
            estCompletion = build.estimatedCompletionDate
            actualStart = build.actualStartDate
            actualCompletion = build.actualCompletionDate
            hasEstStart = build.estimatedStartDate != nil
            hasEstCompletion = build.estimatedCompletionDate != nil
            hasActualStart = build.actualStartDate != nil
            hasActualCompletion = build.actualCompletionDate != nil
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AVIATheme.background)
    }

    private func row(label: String, icon: String, color: Color, hasValue: Binding<Bool>, value: Binding<Date?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 22)
                Text(label)
                    .font(.neueCaptionMedium)
                    .foregroundStyle(AVIATheme.textPrimary)
                Spacer()
                Toggle("", isOn: hasValue)
                    .labelsHidden()
                    .tint(AVIATheme.timelessBrown)
            }
            if hasValue.wrappedValue {
                DatePicker("", selection: Binding(
                    get: { value.wrappedValue ?? .now },
                    set: { value.wrappedValue = $0 }
                ), displayedComponents: .date)
                .labelsHidden()
                .tint(AVIATheme.timelessBrown)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func save() async {
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        let success = await viewModel.updateBuildSchedule(
            buildId: build.id,
            estimatedStartDate: hasEstStart ? (estStart ?? .now) : nil,
            estimatedCompletionDate: hasEstCompletion ? (estCompletion ?? .now) : nil,
            actualStartDate: hasActualStart ? (actualStart ?? .now) : nil,
            actualCompletionDate: hasActualCompletion ? (actualCompletion ?? .now) : nil
        )
        if !success {
            let detail = SupabaseService.shared.lastUpsertError ?? "Unknown Supabase error."
            saveError = "Couldn’t save schedule. \(detail)\n\nLikely cause: the schedule columns are missing from the builds table. Run migration 20260526_build_timeline_schedule.sql."
            return
        }
        dismiss()
    }
}
