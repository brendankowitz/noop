import SwiftUI
import StrandDesign

// MARK: - Hearth progress ring (bknoop fork)
//
// The Today hero's three score cells drew a `LiquidVessel` (a filling blob) before this retheme.
// The Hearth mockup's hero arcs are a plain circular progress ring instead — a faint full-circle
// track plus a trimmed arc, starting at 12 o'clock and sweeping clockwise to `fraction`.
struct HearthProgressRing: View {
    /// 0...1, or nil for "no data yet" (draws the empty track only).
    var fraction: Double?
    var lineWidth: CGFloat = 3
    /// Track/fill default to translucent white — correct on top of a colored sky or a dark ink card
    /// (Today's hero cells), where a per-domain tint would fight the sky instead of reading as one
    /// calm hero (the mockup's own choice). SleepView's hero sits on a plain light card instead, so it
    /// passes explicit opaque colors here rather than white-on-white.
    var trackColor = Color.white.opacity(0.22)
    var fillColor = Color.white.opacity(0.92)
    /// When `true` (the default — Today's hero cells), the ring owns its own draw-in animation on
    /// appear/change. When `false` (SleepView's hero, which already wraps its own `@State` fraction
    /// in `withAnimation`), the trim reads `fraction` directly with no internal animation state, so it
    /// rides the CALLER's animation transaction instead of layering a second one on top — two
    /// independent 0.9s ease-outs chasing the same value produced a visible stutter.
    var animated: Bool = true

    @State private var animatedFraction: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clampedFraction: Double { max(0, min(1, fraction ?? 0)) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: animated ? animatedFraction : clampedFraction)
                .stroke(fillColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .onAppear { if animated { setFraction(fraction, animate: false) } }
        .onChangeCompat(of: fraction) { if animated { setFraction($0, animate: true) } }
    }

    private func setFraction(_ f: Double?, animate: Bool) {
        let target = max(0, min(1, f ?? 0))
        guard animate, !reduceMotion else { animatedFraction = target; return }
        withAnimation(.easeOut(duration: 0.9)) { animatedFraction = target }
    }
}

#if DEBUG
#Preview("HearthProgressRing") {
    HStack(spacing: 24) {
        HearthProgressRing(fraction: nil).frame(width: 62, height: 62)
        HearthProgressRing(fraction: 0.3).frame(width: 62, height: 62)
        HearthProgressRing(fraction: 0.72).frame(width: 62, height: 62)
        HearthProgressRing(fraction: 1.0).frame(width: 62, height: 62)
    }
    .padding(40)
    .background(Color(red: 0.3, green: 0.4, blue: 0.55))
}
#endif
