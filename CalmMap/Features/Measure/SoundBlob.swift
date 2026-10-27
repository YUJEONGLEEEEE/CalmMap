import SwiftUI

struct SoundBlob: View {
    var level: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { canvas, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let base = min(size.width, size.height) * 0.36 * (0.85 + 0.2 * level)
                let energy = 0.04 + 0.1 * level
                var path = Path()
                let steps = 72
                for step in 0...steps {
                    let angle = Double(step) / Double(steps) * 2 * .pi
                    let wobble = 1
                        + energy * sin(angle * 3 + time * 1.6)
                        + energy * 0.6 * sin(angle * 5 - time * 1.1)
                    let point = CGPoint(
                        x: center.x + cos(angle) * base * wobble,
                        y: center.y + sin(angle) * base * wobble
                    )
                    step == 0 ? path.move(to: point) : path.addLine(to: point)
                }
                path.closeSubpath()
                canvas.fill(
                    path,
                    with: .radialGradient(
                        Gradient(colors: [
                            Color.calmInk.opacity(0.45),
                            Color.calmInk.opacity(0.16),
                            Color.calmInk.opacity(0)
                        ]),
                        center: center,
                        startRadius: 0,
                        endRadius: base * 1.25
                    )
                )
            }
        }
        .animation(.easeOut(duration: 0.3), value: level)
        .accessibilityHidden(true)
    }
}

#Preview {
    SoundBlob(level: 0.6)
        .frame(height: 240)
}
