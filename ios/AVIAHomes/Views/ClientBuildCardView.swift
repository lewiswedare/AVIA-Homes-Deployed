import SwiftUI

struct ClientBuildCardView: View {
    let build: ClientBuild
    let showStaffInfo: Bool

    init(build: ClientBuild, showStaffInfo: Bool = false) {
        self.build = build
        self.showStaffInfo = showStaffInfo
    }

    var body: some View {
        BentoCard(cornerRadius: 13) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Text(build.client.initials.isEmpty ? "?" : build.client.initials)
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.aviaWhite)
                        .frame(width: 42, height: 42)
                        .background(AVIATheme.primaryGradient)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(build.clientDisplayName)
                            .font(.neueSubheadlineMedium)
                            .foregroundStyle(AVIATheme.textPrimary)
                        HStack(spacing: 4) {
                            Text("\(build.homeDesign) · \(build.lotNumber)")
                                .font(.neueCaption)
                                .foregroundStyle(AVIATheme.textSecondary)
                            if build.isCustom {
                                Text("CUSTOM")
                                    .font(.neueCorpMedium(7))
                                    .kerning(0.3)
                                    .foregroundStyle(AVIATheme.aviaWhite)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(AVIATheme.timelessBrown)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.neueCaption2)
                        .foregroundStyle(AVIATheme.textTertiary)
                }
                .padding(16)

                Rectangle().fill(AVIATheme.surfaceBorder).frame(height: 1)

                if build.isAwaitingRegistration {
                    awaitingRegistrationBanner
                } else {
                    HStack(spacing: 16) {
                        buildMetric(
                            icon: "hammer.fill",
                            value: build.statusLabel,
                            label: "Stage"
                        )

                        Rectangle()
                            .fill(AVIATheme.surfaceBorder)
                            .frame(width: 1, height: 32)

                        buildMetric(
                            icon: "chart.bar.fill",
                            value: "\(Int(build.overallProgress * 100))%",
                            label: "Progress"
                        )

                        Rectangle()
                            .fill(AVIATheme.surfaceBorder)
                            .frame(width: 1, height: 32)

                        buildMetric(
                            icon: "mappin.circle.fill",
                            value: build.estate.components(separatedBy: ",").first ?? build.estate,
                            label: "Estate"
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AVIATheme.timelessBrown.opacity(0.1))
                                .frame(height: 4)
                            Capsule()
                                .fill(AVIATheme.primaryGradient)
                                .frame(width: max(0, geo.size.width * build.overallProgress), height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
            }
        }
    }

    private var awaitingRegistrationBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 18))
                    .foregroundStyle(AVIATheme.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Awaiting Site Registration")
                        .font(.neueCaptionMedium)
                        .foregroundStyle(AVIATheme.textPrimary)
                    if let regStage = build.awaitingRegistrationStage, let estDate = regStage.estimatedEndDate {
                        Text("Est. \(estDate.formatted(.dateTime.month(.abbreviated).day().year()))")
                            .font(.neueCaption2)
                            .foregroundStyle(AVIATheme.textSecondary)
                    }
                }

                Spacer()

                Text(build.estate.components(separatedBy: ",").first ?? build.estate)
                    .font(.neueCaption2)
                    .foregroundStyle(AVIATheme.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AVIATheme.warning.opacity(0.1))
                        .frame(height: 4)
                    Capsule()
                        .fill(AVIATheme.warning.opacity(0.5))
                        .frame(width: max(0, geo.size.width * 0.05), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
    }

    private func buildMetric(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textPrimary)
                .lineLimit(1)
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
