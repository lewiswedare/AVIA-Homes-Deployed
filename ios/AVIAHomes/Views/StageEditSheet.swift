import SwiftUI

struct StageEditSheet: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    let build: ClientBuild
    let stage: BuildStage
    @State private var progress: Double
    @State private var notes: String
    @State private var isSaving = false

    init(build: ClientBuild, stage: BuildStage) {
        self.build = build
        self.stage = stage
        _progress = State(initialValue: stage.progress)
        _notes = State(initialValue: stage.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    stageHeader

                    BentoCard(cornerRadius: 16) {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Progress", systemImage: "chart.bar.fill")
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)

                            VStack(spacing: 10) {
                                HStack {
                                    Text("0%")
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                    Spacer()
                                    Text("\(Int(progress * 100))%")
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(AVIATheme.timelessBrown)
                                    Spacer()
                                    Text("100%")
                                        .font(.neueCaption2)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                }

                                Slider(value: $progress, in: 0...1, step: 0.05)
                                    .tint(AVIATheme.timelessBrown)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(AVIATheme.timelessBrown.opacity(0.1)).frame(height: 8)
                                        Capsule().fill(AVIATheme.primaryGradient).frame(width: max(0, geo.size.width * progress), height: 8)
                                    }
                                }
                                .frame(height: 8)
                            }

                            HStack(spacing: 8) {
                                quickProgressButton(label: "0%", value: 0)
                                quickProgressButton(label: "25%", value: 0.25)
                                quickProgressButton(label: "50%", value: 0.5)
                                quickProgressButton(label: "75%", value: 0.75)
                                quickProgressButton(label: "100%", value: 1.0)
                            }
                        }
                        .padding(16)
                    }

                    BentoCard(cornerRadius: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Notes", systemImage: "note.text")
                                .font(.neueSubheadlineMedium)
                                .foregroundStyle(AVIATheme.textPrimary)

                            TextEditor(text: $notes)
                                .font(.neueSubheadline)
                                .foregroundStyle(AVIATheme.textPrimary)
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .background(AVIATheme.cardBackgroundAlt)
                                .clipShape(.rect(cornerRadius: 10))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(AVIATheme.surfaceBorder, lineWidth: 1)
                                }
                        }
                        .padding(16)
                    }

                    if let startDate = stage.startDate {
                        BentoCard(cornerRadius: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Timeline", systemImage: "calendar")
                                    .font(.neueSubheadlineMedium)
                                    .foregroundStyle(AVIATheme.textPrimary)

                                HStack {
                                    Text("Started")
                                        .font(.neueCaption)
                                        .foregroundStyle(AVIATheme.textTertiary)
                                    Spacer()
                                    Text(startDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(.neueCaptionMedium)
                                        .foregroundStyle(AVIATheme.textPrimary)
                                }

                                if let completionDate = stage.completionDate {
                                    HStack {
                                        Text("Completed")
                                            .font(.neueCaption)
                                            .foregroundStyle(AVIATheme.textTertiary)
                                        Spacer()
                                        Text(completionDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.neueCaptionMedium)
                                            .foregroundStyle(AVIATheme.success)
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }

                    Button(action: saveStage) {
                        Group {
                            if isSaving {
                                ProgressView().tint(AVIATheme.aviaWhite)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Update Stage")
                                }
                                .font(.neueSubheadlineMedium)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(.rect(cornerRadius: 14))
                    }
                    .disabled(isSaving)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(AVIATheme.background)
            .navigationTitle("Edit Stage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(AVIATheme.timelessBrown)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(AVIATheme.background)
    }

    private var stageHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: stage.status == .completed ? "checkmark.circle.fill" : stage.status == .inProgress ? "circle.dotted.circle.fill" : "circle")
                .font(.system(size: 28))
                .foregroundStyle(stage.status == .completed ? AVIATheme.success : stage.status == .inProgress ? AVIATheme.warning : AVIATheme.textTertiary)

            VStack(alignment: .leading, spacing: 3) {
                Text(stage.name)
                    .font(.neueCorpMedium(18))
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(stage.description)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
            }

            Spacer()
        }
    }

    private func quickProgressButton(label: String, value: Double) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                progress = value
            }
        } label: {
            Text(label)
                .font(.neueCaption2Medium)
                .foregroundStyle(abs(progress - value) < 0.01 ? AVIATheme.aviaWhite : AVIATheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(abs(progress - value) < 0.01 ? AVIATheme.timelessBrown : AVIATheme.cardBackgroundAlt)
                .clipShape(.rect(cornerRadius: 8))
        }
    }

    private func saveStage() {
        isSaving = true
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            viewModel.updateBuildStageProgress(
                buildId: build.id,
                stageId: stage.id,
                progress: progress,
                notes: notes.isEmpty ? nil : notes
            )
            isSaving = false
            dismiss()
        }
    }
}
