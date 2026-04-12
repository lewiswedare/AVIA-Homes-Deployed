import SwiftUI

struct CountdownUnit: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(String(format: "%02d", value))
                .font(.neueCorpMedium(24))
                .foregroundStyle(AVIATheme.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.3), value: value)
            Text(label)
                .font(.neueCorpMedium(9))
                .kerning(1.0)
                .foregroundStyle(AVIATheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CountdownSeparator: View {
    var body: some View {
        Text(":")
            .font(.neueCorpMedium(20))
            .foregroundStyle(AVIATheme.textTertiary)
            .offset(y: -4)
    }
}
