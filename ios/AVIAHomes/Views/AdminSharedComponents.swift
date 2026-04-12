import SwiftUI

struct AdminMetricCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        BentoCard(cornerRadius: 16) {
            VStack(alignment: .leading, spacing: 8) {
                BentoIconCircle(icon: icon, color: color)
                Text(value)
                    .font(.neueCorpMedium(32))
                    .foregroundStyle(AVIATheme.textPrimary)
                Text(label)
                    .font(.neueCaption)
                    .foregroundStyle(AVIATheme.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct AdminProgressLabel: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(count) \(label)")
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
    }
}

struct AdminQuickActionContent: View {
    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.neueSubheadlineMedium)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12))
                .clipShape(Circle())
            Text(label)
                .font(.neueCaptionMedium)
                .foregroundStyle(AVIATheme.textPrimary)
                .lineLimit(1)
            Spacer()
        }
        .padding(12)
        .background(AVIATheme.cardBackground)
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14).stroke(AVIATheme.surfaceBorder, lineWidth: 1)
        }
    }
}

struct AdminPendingRow: View {
    let icon: String
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.neueCorp(12))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.12))
                .clipShape(Circle())
            Text(label)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textPrimary)
            Spacer()
            Text("\(count)")
                .font(.neueCaptionMedium)
                .foregroundStyle(count > 0 ? color : AVIATheme.textTertiary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(count > 0 ? color.opacity(0.1) : AVIATheme.surfaceElevated)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct AdminWorkloadStat: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.neueCaptionMedium)
                .foregroundStyle(color)
            Text(label)
                .font(.neueCaption2)
                .foregroundStyle(AVIATheme.textTertiary)
        }
    }
}

struct AdminEmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(AVIATheme.textTertiary)
            Text(title)
                .font(.neueSubheadlineMedium)
                .foregroundStyle(AVIATheme.textSecondary)
            Text(subtitle)
                .font(.neueCaption)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
