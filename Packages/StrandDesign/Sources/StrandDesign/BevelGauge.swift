import SwiftUI

// MARK: - BevelGauge — the shared open-gauge primitive (Hearth: flat, no gradients)
//
// The shared instrument behind RecoveryRing and StrainGauge: a 240° open gauge with
//   • a faint full-span track ring carved from `surfaceInset` (the "well")
//   • a FLAT solid-colour progress arc, round-capped — stroked in a single `tipColor`
//     chosen for the value's current state/zone (recovery = value colour, effort = ember→amber
//     tint sampled at the fraction, etc.). Hearth rule: skies are the ONLY gradients in the app,
//     so the arc is a flat stroke, never a swept AngularGradient across the domain ramp.
//   • a centred SF Pro **Rounded** number with an "of N" caption + state word
//
// It owns no domain logic — callers pass the fraction, the flat arc colour (`tipColor`), and the
// centre read-out strings. RecoveryRing / StrainGauge keep their own public init signatures and
// delegate their visuals here, so every screen re-skins without any call-site change.

public struct BevelGauge: View {

    /// Fill fraction 0...1 of the 240° span.
    public var fraction: Double
    /// The flat colour of the progress arc + the state word — one solid tone for the value's
    /// current state/zone (usually the domain ramp sampled at `fraction`). Not a gradient.
    public var tipColor: Color
    /// Big centred number, already formatted (e.g. "87" or "12.4").
    public var numberText: String
    /// Small caption under the number (e.g. "of 100" / "of 21"). nil hides it.
    public var captionText: String?
    /// State word above/below the number (e.g. "PRIMED"). nil hides it.
    public var stateText: String?
    /// Optional supporting line under the read-out.
    public var supporting: String?
    public var diameter: CGFloat
    public var lineWidth: CGFloat
    public var showsLabel: Bool
    /// Animated draw-in fraction supplied by the caller (so it owns the @State + animation).
    public var animatedFraction: Double
    /// Whether the bloom is at full (vs resting) intensity — caller drives the breathe pulse.
    public var bloomActive: Bool

    public init(
        fraction: Double,
        tipColor: Color,
        numberText: String,
        captionText: String? = nil,
        stateText: String? = nil,
        supporting: String? = nil,
        diameter: CGFloat = 200,
        lineWidth: CGFloat = 16,
        showsLabel: Bool = true,
        animatedFraction: Double,
        bloomActive: Bool = true
    ) {
        self.fraction = fraction
        self.tipColor = tipColor
        self.numberText = numberText
        self.captionText = captionText
        self.stateText = stateText
        self.supporting = supporting
        self.diameter = diameter
        self.lineWidth = lineWidth
        self.showsLabel = showsLabel
        self.animatedFraction = animatedFraction
        self.bloomActive = bloomActive
    }

    private let arcSpanDegrees: Double = 240
    private var startAngle: Angle { .degrees(150) }
    private var endAngle: Angle { .degrees(150 + arcSpanDegrees) }

    public var body: some View {
        ZStack {
            // STATIC BACKDROP: the faint full-span track. It doesn't depend on `animatedFraction`, so
            // SwiftUI/CoreAnimation caches it as an unchanged layer and does NOT re-render it when only
            // the arc animates. No .drawingGroup() — a per-instance offscreen flatten cost more than it
            // saved (it was part of the v7.0.2 lag regression).
            staticBackdrop
                .frame(width: diameter, height: diameter)

            // LIVE LAYER: the flat progress arc, kept OUTSIDE any drawingGroup so the shape's
            // `animatableData` still animates smoothly.
            animatedArc

            if showsLabel { centerLabel }
        }
        .frame(width: diameter, height: diameter)
    }

    /// The non-animating backdrop: the faint full-span track "well" the score arc sits in.
    private var staticBackdrop: some View {
        arcShape(to: 1.0)
            .stroke(StrandPalette.surfaceInset,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }

    /// The live layer: a FLAT solid-colour arc (round-capped) driven by `animatedFraction`. Hearth:
    /// one flat tone for the value's current state — no swept gradient, no end-cap bead or glow (the
    /// round cap already gives the tip a clean rounded end). `bloomActive` stays in the signature so
    /// callers are unchanged, but the flat instrument renders no bloom.
    private var animatedArc: some View {
        arcShape(to: animatedFraction)
            .stroke(tipColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
    }

    private var centerLabel: some View {
        VStack(spacing: 2) {
            Text(numberText)
                // The gauge numeral is a "big number" role, so it follows `StrandFont.displayWeight`
                // (upstream default .bold; a fork can dial it thin — the Hearth mockup's gauge numbers
                // are thin, not a heavy gauge digit) instead of a hardcoded .bold literal.
                .font(StrandFont.rounded(diameter * 0.30, weight: StrandFont.displayWeight))
                .foregroundStyle(StrandPalette.textPrimary)
                .contentTransition(.numericText())
            if let captionText {
                Text(captionText)
                    .font(StrandFont.rounded(diameter * 0.085, weight: .medium))
                    .foregroundStyle(StrandPalette.textTertiary)
            }
            if let stateText {
                // Scale the state word WITH the gauge, like the number (0.30·d) and caption (0.085·d).
                // `min(11, …)` pins it to the original 11pt overline on the large solo-hero rings (≥130pt)
                // — byte-identical there — and shrinks it on the small three-up rings, where a fixed 11pt
                // word overflowed the arc and collided with the number/caption. Uses a *scaled overline*
                // (not rounded()) so Dynamic-Type text-scaling is preserved. Thanks @claypilat (#403).
                let stateSize = min(11, diameter * 0.085)
                Text(stateText)
                    .font(StrandFont.overlineScaled(stateSize))
                    .tracking(StrandFont.overlineTracking * stateSize / 11)
                    .foregroundStyle(tipColor)
                    .padding(.top, 2)
            }
            if let supporting {
                Text(supporting)
                    .font(StrandFont.footnote)
                    .foregroundStyle(StrandPalette.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: diameter * 0.78)
                    .padding(.top, 2)
            }
        }
    }

    private func arcShape(to fraction: Double) -> RecoveryArc {
        RecoveryArc(startAngle: startAngle, spanDegrees: arcSpanDegrees,
                    fraction: fraction, lineWidth: lineWidth)
    }
}

#if DEBUG
#Preview("BevelGauge") {
    HStack(spacing: 24) {
        BevelGauge(
            fraction: 0.78,
            tipColor: StrandPalette.recoveryColor(78), numberText: "78",
            captionText: "of 100", stateText: "PRIMED",
            diameter: 200, animatedFraction: 0.78
        )
        BevelGauge(
            fraction: 0.55,
            tipColor: StrandPalette.strainColor(55), numberText: "11.6",
            captionText: "of 21", stateText: "MODERATE",
            diameter: 200, animatedFraction: 0.55
        )
    }
    .padding(40)
    .background(StrandPalette.surfaceBase)
    .preferredColorScheme(.dark)
}
#endif
