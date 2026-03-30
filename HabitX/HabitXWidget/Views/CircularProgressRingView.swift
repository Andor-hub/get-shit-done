import SwiftUI

/// Reusable circular progress ring for widget views.
/// Shows a filled arc tracking progress from 0.0 to 1.0.
/// When `isCompleted` is true, the center shows a checkmark instead of the fraction
/// (fraction label is handled by the caller for context-specific formatting).
///
/// Per D-01: progress ring with accent fill color
/// Per D-02: checkmark in center replaces fraction when habit is complete
/// Per D-03: unfilled track = systemGray4, filled arc = appAccent color
struct CircularProgressRingView: View {
    let progress: Double
    let isCompleted: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            // Track ring — always full circle (D-03: unfilled = system gray)
            Circle()
                .stroke(Color(.systemGray4), lineWidth: size * 0.12)

            // Progress arc — filled from 0 to progress (D-03: filled = appAccent)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    Color.appAccent,
                    style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Center content — checkmark when complete (D-02)
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.28, weight: .bold))
                    .foregroundStyle(Color.appAccent)
            }
        }
        .frame(width: size, height: size)
    }
}
