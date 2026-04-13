import SwiftUI

struct AdminBuildStageEditor: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let buildId: String
    let stage: BuildStage
    let sortOrder: Int

    @State private var name: String = ""
    @State private var stageDescription: String = ""
    @State private var status: BuildStage.StageStatus = .upcoming
    @State private var progress: Double = 0
    @State private var startDate: Date?
    @State private var completionDate: Date?
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var hasStartDate = false
    @State private var hasCompletionDate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BentoCard(cornerRadius: 16) {
                        VStack(spacing: 14) {
                            field(label: "Stage Name") {
                                TextField("e.g. Slab", text: $name)
                                    .font(.neueSubheadline)
                            }

                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                            field(label: "Description") {
                                TextField("Stage description", text: $stageDescription)
                                    .font(.neueSubheadline)
                            }

                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                            field(label: "Status") {
                                Picker("Status", selection: $status) {
                                    Text("Upcoming").tag(BuildStage.StageStatus.upcoming)
                                    Text("In Progress").tag(BuildStage.StageStatus.inProgress)
                                    Text("Completed").tag(BuildStage.StageStatus.completed)
                                }
                                .pickerStyle(.segmented)
                            }

                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                            field(label: "Progress — \(Int(progress * 100))%") {
                                Slider(value: $progress, in: 0...1, step: 0.05)
                                    .tint(AVIATheme.teal)
                            }

                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                            field(label: "Start Date") {
                                Toggle("Set Start Date", isOn: $hasStartDate)
                                    .tint(AVIATheme.teal)
                                if hasStartDate {
                                    DatePicker("", selection: Binding(
                                        get: { startDate ?? .now },
                                        set: { startDate = $0 }
                                    ), displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(AVIATheme.teal)
                                }
                            }

                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                            field(label: "Completion Date") {
                                Toggle("Set Completion Date", isOn: $hasCompletionDate)
                                    .tint(AVIATheme.teal)
                                if hasCompletionDate {
                                    DatePicker("", selection: Binding(
                                        get: { completionDate ?? .now },
                                        set: { completionDate = $0 }
                                    ), displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(AVIATheme.teal)
                                }
                            }

                            Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                            field(label: "Notes") {
                                TextEditor(text: $notes)
                                    .font(.neueSubheadline)
                                    .frame(minHeight: 80)
                                    .scrollContentBackground(.hidden)
                            }
                        }
                        .padding(16)
                    }

                    PremiumButton("Save Stage", icon: "checkmark", style: .primary) {
                        Task { await save() }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(AVIATheme.background)
            .navigationTitle("Edit Stage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.neueSubheadline)
                }
            }
            .onAppear {
                name = stage.name
                stageDescription = stage.description
                status = stage.status
                progress = stage.progress
                startDate = stage.startDate
                completionDate = stage.completionDate
                notes = stage.notes ?? ""
                hasStartDate = stage.startDate != nil
                hasCompletionDate = stage.completionDate != nil
            }
        }
    }

    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.neueCaption2Medium)
                .foregroundStyle(AVIATheme.textTertiary)
                .kerning(0.5)
            content()
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let updated = BuildStage(
            id: stage.id,
            name: name,
            description: stageDescription,
            status: status,
            progress: progress,
            startDate: hasStartDate ? (startDate ?? .now) : nil,
            completionDate: hasCompletionDate ? (completionDate ?? .now) : nil,
            notes: notes.isEmpty ? nil : notes,
            photoCount: stage.photoCount
        )

        await SupabaseService.shared.updateBuildStage(updated, buildId: buildId, sortOrder: sortOrder)
        await viewModel.refreshBuildsAndAssignments()
        dismiss()
    }
}
