import SwiftUI
import StrandDesign

// MARK: - About Apple Watch data
//
// The honest "what your Apple Watch is good at, and where it's lighter" page (M2 of the
// Watch-as-a-device project). NOOP can run off only an Apple Watch (the phone computes our
// Charge / Rest / Effort / Fitness Age live from HealthKit) but the watch is not a chest
// strap, and this page says so plainly. It renders the per-metric capability + confidence
// table from the design spec, the HRV-sampling explanation (why recovery calibrates over
// about a week), and the SpO2 caveat (the newest US units dropped the sensor).
//
// This is content only: it reads from no store and holds no live state, so it renders the
// SAME on macOS and iOS. The actual permission request lives in the setup flow
// (AppleWatchSetupView), which this page links to. Reachable from Settings → About.
//
// Hearth layout (mockup 1c, right frame): reference material, not a lived moment — so it drops the
// sky for FLAT INK and reads as three things only: one Group card carrying the whole capability
// table, one sage Conclusion card for the single conclusion this page draws (why recovery
// calibrates), and one Group-style row into the setup flow. The former per-metric standalone cards
// (intro, blood-oxygen note) are gone as separate cards — nothing they said was dropped, it moved
// into the row that owns the claim (wrist temperature, blood oxygen) or into the header's own line.
//
// Honest tone, plain voice, no fabricated numbers. Every confidence label here is the same
// honest "Great / Good / Calibrating / Not available" stance the scores use on Today.

/// One row of the capability/confidence table: a metric, where the watch sits on it, and a
/// plain line of why. The confidence drives the row's pill, so a glance reads honestly.
private struct WatchMetric: Identifiable {
    enum Confidence {
        case great        // use it as-is, the watch is strong here
        case good         // solid, with a small caveat
        case calibrating  // needs a baseline first, no fabricated number until then
        case unavailable  // the sensor or model can't honestly support it

        var pillLabel: String {
            switch self {
            case .great:        return String(localized: "Great")
            case .good:         return String(localized: "Good")
            case .calibrating:  return String(localized: "Calibrating")
            case .unavailable:  return String(localized: "Not available")
            }
        }

        var tone: StrandTone {
            switch self {
            case .great:        return .positive
            case .good:         return .accent
            case .calibrating:  return .warning
            case .unavailable:  return .neutral
            }
        }
    }

    let id = UUID()
    let metric: String
    let confidence: Confidence
    let detail: String
}

struct AppleWatchAboutView: View {
    /// Optional hook so the page can present the setup/permission flow. The About page links to
    /// it as its primary call to action; left nil (e.g. on macOS, which has no HealthKit, or when
    /// the setup flow itself opened this page) the row is hidden and the page reads as pure
    /// reference content.
    var onStartSetup: (() -> Void)?

    init(onStartSetup: (() -> Void)? = nil) {
        self.onStartSetup = onStartSetup
    }

    // The honest table, straight from the spec's scoring + confidence map. Order runs from what
    // the watch is strongest at down to what it can't honestly do, so the page reads as a fair
    // appraisal rather than a sales pitch.
    private let metrics: [WatchMetric] = [
        WatchMetric(metric: String(localized: "Sleep / Rest"),
                    confidence: .great,
                    detail: String(localized: "Apple's own sleep stages drive Rest directly. This is one of the watch's strengths.")),
        WatchMetric(metric: String(localized: "Steps & workouts"),
                    confidence: .great,
                    detail: String(localized: "Steps, active energy and logged workouts feed Effort. Dense and reliable.")),
        WatchMetric(metric: String(localized: "Fitness Age"),
                    confidence: .great,
                    detail: String(localized: "Built from Apple's cardio-fitness VO₂ max estimate, the same number the Fitness app shows.")),
        WatchMetric(metric: String(localized: "Effort"),
                    confidence: .good,
                    detail: String(localized: "Heart rate plus active energy give a solid daily cardiovascular load. An on-watch workout sharpens it further.")),
        WatchMetric(metric: String(localized: "Recovery / Charge"),
                    confidence: .calibrating,
                    detail: String(localized: "Led by your heart-rate variability versus your own baseline. The watch samples HRV rather than streaming it, so this needs about a week of nights to calibrate. Until then NOOP shows \u{201C}needs more data\u{201D}, never a guessed number.")),
        WatchMetric(metric: String(localized: "Skin temperature"),
                    confidence: .good,
                    detail: String(localized: "From the watch's wrist-temperature sensor during sleep, on Series 8 and later. Older models don't have the sensor, so it reads \u{201C}not available\u{201D} rather than zero.")),
        WatchMetric(metric: String(localized: "Blood oxygen (SpO₂)"),
                    confidence: .unavailable,
                    detail: String(localized: "Trend only where supported, and Apple removed the SpO₂ sensor from the newest US units, so on those it simply isn't there. NOOP shows nothing rather than a fake reading.")),
    ]

    var body: some View {
        ScreenScaffold(title: "About Apple Watch data",
                       subtitle: "A watch isn't a chest strap, and NOOP would rather say so than average the difference away.",
                       lazy: true,
                       // Reference material, not a moment — flat ink, per the mockup's own
                       // sky-vs-ink discipline.
                       topBackground: liquidFlatInkBackground()) {
            capabilityCard
            hrvCard
            if let onStartSetup {
                setupRow(onStartSetup)
            }
            footerNote
        }
    }

    // MARK: - Capability + confidence table

    private var capabilityCard: some View {
        GroupCard("WHAT THE WATCH CAN DO") {
            // The card's own sub-caption. It sits as the first child so the Group card's between-child
            // hairline lands under it — the mockup's header block, then a ruled row per metric.
            Text("NOOP can run off only an Apple Watch. Here's each metric, where your watch sits on it, and why.")
                .font(StrandFont.caption)
                .foregroundStyle(StrandPalette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 14)

            ForEach(metrics) { item in
                metricRow(item)
            }
        }
    }

    /// A `GroupRow`-shaped row that lets the "why" WRAP: the shared `GroupRow` floors its subtitle at
    /// one line, and every honest explanation here is a full sentence. Same anatomy (title left, pill
    /// right, detail beneath), so it reads as part of the same divided list.
    private func metricRow(_ item: WatchMetric) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 12) {
                Text(item.metric)
                    .font(StrandFont.body)
                    .foregroundStyle(StrandPalette.textPrimary)
                Spacer(minLength: 8)
                StatePill(LocalizedStringKey(item.confidence.pillLabel),
                          tone: item.confidence.tone, showsDot: false)
            }
            Text(item.detail)
                .font(.system(size: 12.5))
                .foregroundStyle(StrandPalette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // One accessible element per metric: the screen reader hears the metric, its confidence,
        // and the plain explanation as a single, honest unit instead of three loose fragments.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.metric). \(item.confidence.pillLabel). \(item.detail)")
    }

    // MARK: - HRV-sampling explanation (the one conclusion this page draws)

    private var hrvCard: some View {
        ConclusionCard {
            VStack(alignment: .leading, spacing: 11) {
                Text("WHY RECOVERY CALIBRATES OVER ABOUT A WEEK")
                    .font(StrandFont.overline)
                    .tracking(StrandFont.overlineTracking)
                    .foregroundStyle(StrandPalette.accentHover)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Recovery, NOOP's Charge score, is led by your heart-rate variability measured against your own personal baseline. A chest strap streams beat-to-beat data densely all night, so it can learn that baseline fast. An Apple Watch instead samples HRV, a handful of readings through the day plus overnight, so the signal is real but sparser.")
                    .font(StrandFont.body)
                    .foregroundStyle(StrandPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("That's why a watch-only Charge starts out \u{201C}Calibrating\u{201D}. NOOP needs about seven nights of your HRV to learn what normal looks like for you. Until it has them it withholds the score rather than guess. Once the baseline is set, your Charge appears with its confidence, on the same 0-100 scale as a strap's.")
                    .font(StrandFont.body)
                    .foregroundStyle(StrandPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Start setup (injected by the caller)

    private func setupRow(_ start: @escaping () -> Void) -> some View {
        GroupCard {
            Button(action: start) {
                GroupRow(leading: .icon("applewatch", StrandPalette.accent),
                         title: "Set up Apple Watch",
                         // One line: `GroupRow` floors its subtitle at one line, and anything longer
                         // truncates mid-sentence on an iPhone-width row.
                         subtitle: "Connect Apple Health",
                         showsChevron: true)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel("Set up Apple Watch")
            .accessibilityHint("Opens the Apple Watch setup and Health permission")
        }
    }

    private var footerNote: some View {
        Text("These are independent estimates computed on your device from your Apple Health data, not medical advice. Confidence labels are honest about how much NOOP knows so far.")
            .font(StrandFont.footnote)
            .foregroundStyle(StrandPalette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }
}

#if DEBUG
#Preview("About Apple Watch data") {
    NavigationStack {
        AppleWatchAboutView(onStartSetup: {})
    }
}
#endif
