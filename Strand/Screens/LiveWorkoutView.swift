import SwiftUI
import StrandDesign
import StrandAnalytics
import WhoopStore

/// Live workout mode (#238) — the in-exercise screen: a big live heart rate, the current HR zone,
/// elapsed time, and live effort building, all from the SAME live feed and scorers the rest of the
/// app uses (no invented numbers). Presented while a manual workout is active, entered from the
/// Start-workout control on Live. The ✕ in the control bar stops the workout (behind a confirm) and
/// dismisses; the chevron closes the screen and leaves the recording running.
///
/// Live HR is the smoothed `AppModel.bpm`; the zone is derived from the user's HR-max via the shared
/// `HRZones` model; elapsed time ticks from the workout's start (a TimelineView, no manual Timer);
/// effort is the running `ActiveWorkout.liveStrain` (StrainScorer over the captured window).
///
/// Hearth (bknoop fork) layout — mockup §1e, the heart-rate-led take. Not a card list: the screen is
/// one full-bleed moment on its own dark-plum sky, with HR leading, Effort second, the zone rail and
/// a frosted stat strip beneath, and a floating control bar pinned to the bottom. Every number is the
/// same live value the card layout showed; only the presentation changed.
struct LiveWorkoutView: View {
    @EnvironmentObject private var model: AppModel
    // PERF (scroll/recompose): this screen deliberately does NOT observe `LiveState` directly. A connected
    // strap publishes `LiveState` ~1 Hz (HR + each R-R packet, plus sensor frames), and an
    // `@EnvironmentObject live` here would invalidate the WHOLE body on every tick — the HR hero, effort
    // read-out, zone rail and stat strip all re-evaluate even though they read from `model` (smoothed bpm +
    // scorers), not `live`. The only region that genuinely needs `live` is the additive sensor readout
    // (speed / cadence / power), so it's extracted into the small `SensorRowIfPresent` leaf below that
    // owns its OWN `@EnvironmentObject live`. A sensor/R-R packet now re-renders just that row, not the
    // hero. (`model.live` is its own ObservableObject, so the leaf's `live` is the one that sees the
    // @Published changes — exactly as the parent's direct observation did before.)
    let onClose: () -> Void

    /// Effort display scale (#268) — routes the live Effort read-out through the shared helper so it
    /// matches every other surface. Display-only; the captured value stays stored 0–100.
    @AppStorage(UnitPrefs.effortScaleKey) private var effortScaleRaw = EffortScale.hundred.rawValue
    private var effortScale: EffortScale { UnitPrefs.resolveEffortScale(effortScaleRaw) }

    /// Keep the screen awake while recording (#703). Opt-in, default off; the toggle lives in Settings.
    /// Read here so we can hold the idle timer off only while this in-exercise screen is up and release it
    /// the moment it leaves, which is exactly the bounded usage Apple asks for. iOS-only (no-op on Mac).
    @AppStorage("workoutKeepScreenOn") private var keepScreenOn = false

    /// Guards the destructive End action behind a confirm (#517) — a stray tap on the stop control
    /// would otherwise end the workout instantly with no way back.
    @State private var showEndConfirm = false

    /// Drives the recording dot's slow breath. Reduce Motion leaves it at rest.
    @State private var recordingPulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var zoneSet: HRZoneSet { HRZones.zones(maxHR: Double(model.profile.hrMax)) }
    private var bpm: Int? { model.bpm ?? Self.demoBPM }
    private var zone: Int { bpm.map { zoneSet.zoneNumber(forBPM: Double($0)) } ?? 0 }
    private var liveStrain: Double { Self.demoStrain ?? (model.activeWorkout?.liveStrain ?? 0) }
    private var avgHr: Int { Self.demoAvgHr ?? (model.activeWorkout?.avgHr ?? 0) }
    private var peakHr: Int { Self.demoPeakHr ?? (model.activeWorkout?.peakHr ?? 0) }

    var body: some View {
        ZStack(alignment: .bottom) {
            workoutSky
            VStack(spacing: 0) {
                recordingRow
                    .screenPadding()
                    .padding(.top, NoopMetrics.space5)
                heroScroll
                controlBar
                    .padding(.horizontal, NoopMetrics.space5)
                    .padding(.bottom, NoopMetrics.space6)
            }
        }
        // If the workout ended elsewhere (process restart cleared it), close the screen.
        .onChangeCompat(of: model.activeWorkout == nil) { gone in if gone { onClose() } }
        // Arm the realtime HR stream while the in-exercise screen is up (#681). On a WHOOP 5/MG live HR
        // only flows while the puffin realtime stream is armed; previously only the Live tab armed it, so
        // starting a manual workout straight from Workouts (Live never opened) left `model.bpm == nil` —
        // captureWorkoutSample bailed on every sample and endWorkout silently discarded the empty
        // session. Ref-counted in AppModel, so when this sheet sits over an already-armed Live tab the
        // two balance and neither disarms the other (mirrors Android LiveWorkoutScreen's DisposableEffect
        // requestRealtimeHr/releaseRealtimeHr). Balanced: one start on appear, one stop on disappear.
        .onAppear {
            model.startRealtimeHR()
            // Hold the display awake for the session only if the user opted in (#703).
            if keepScreenOn { ScreenIdle.keepAwake(true) }
        }
        .onDisappear {
            model.stopRealtimeHR()
            // Always release on the way out so the system idle timer resumes. Even if the toggle was
            // flipped off mid-workout, this clears any hold we placed.
            ScreenIdle.keepAwake(false)
        }
        // Confirm before ending (#517): a stray tap on the stop control used to stop the session and
        // discard the in-progress recording with no way back.
        .alert("End this workout?",
               isPresented: $showEndConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("End workout", role: .destructive) {
                model.endWorkout()
                onClose()
            }
        } message: {
            Text("This stops recording and saves what's captured so far. It can't be resumed.")
        }
    }

    /// The hero column. Centred in whatever height is left between the recording row and the control
    /// bar when it fits, scrollable when it doesn't (a long sport name, a sensor row, or large Dynamic
    /// Type all push it past a small phone).
    private var heroScroll: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: NoopMetrics.space8) {
                    heroHeartRate.staggeredAppear(index: 0)
                    effortBlock.staggeredAppear(index: 1)
                    zoneBar.staggeredAppear(index: 2)
                    statStrip.staggeredAppear(index: 3)
                    // Live GPS distance + pace (#1195) — a self-gating leaf owning its own recorder
                    // observation, so a GPS fix re-renders only this row. Renders nothing until the first
                    // accepted fix, so non-GPS / denied sessions leave the stack unchanged.
                    DistancePaceRowIfPresent(recorder: model.gpsRecorder).staggeredAppear(index: 4)
                    // Live-observing leaf: renders the sensor row (and its entrance stagger) only when a
                    // standard fitness sensor is feeding metrics, refreshing on its own packets without
                    // re-rendering the HR hero / effort read-out above (scroll-stutter isolation).
                    SensorRowIfPresent()
                }
                .screenPadding()
                .padding(.vertical, NoopMetrics.space6)
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .center)
            }
        }
    }

    // MARK: - Sky
    //
    // The mockup's own `radial-gradient(120% 70% at 50% 0%, …)`, reproduced in Canvas. SwiftUI only
    // offers a CIRCULAR radial shading, so the ellipse comes from drawing a circle of radius rx
    // through a context scaled by ry/rx about the core (the core is a fixed point of that transform,
    // so it stays put while the circle squashes to rx × ry) — the same construction `drawRampSky`
    // uses for the Today sky. Colours come from `HearthTheme`, never from a literal here.

    private var workoutSky: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let cx = w * 0.5, cy: CGFloat = 0
            let rx = max(1, w * 1.20), ry = max(1, h * 0.70)
            var g = ctx
            g.translateBy(x: cx, y: cy)
            g.scaleBy(x: 1, y: ry / rx)
            g.translateBy(x: -cx, y: -cy)
            // Oversized in pre-transform space so the image still covers the screen after the squash;
            // Canvas clips to its own bounds, so the excess costs nothing.
            g.fill(Path(CGRect(x: -w * 2, y: -h * 12, width: w * 5, height: h * 30)),
                   with: .radialGradient(
                       Gradient(stops: HearthTheme.liveWorkoutSkyRamp.map {
                           .init(color: $0.color, location: $0.loc)
                       }),
                       center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: rx))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    // MARK: - Recording row

    private var recordingRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: NoopMetrics.space2) {
                Circle()
                    .fill(HearthTheme.onSkyRose)
                    .frame(width: 7, height: 7)
                    .opacity(recordingPulse ? 1 : 0.35)
                Text("RECORDING WORKOUT")
                    .font(StrandFont.overline).tracking(StrandFont.overlineTracking)
                    .foregroundStyle(HearthTheme.onSkyRose)
            }
            .padding(.horizontal, NoopMetrics.space3)
            .padding(.vertical, NoopMetrics.space2)
            .background(Capsule().fill(HearthTheme.onSkyRose.opacity(0.16)))
            Spacer(minLength: NoopMetrics.space3)
            // The sport chosen at start (#519) — real stored state, kept visible so the screen still
            // says WHAT is being recorded now that the old "Workout" title row is gone.
            if let sport = model.activeWorkout?.sport {
                Text(sport)
                    .font(StrandFont.subhead)
                    .foregroundStyle(StrandPalette.onDarkTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                recordingPulse = true
            }
        }
    }

    // MARK: - Hero: heart rate leads

    private var heroHeartRate: some View {
        VStack(spacing: NoopMetrics.space1) {
            Text("HEART RATE")
                .font(StrandFont.overline).tracking(StrandFont.overlineTracking)
                .foregroundStyle(StrandPalette.onDarkSecondary)
            // The big live HR ticks up to its new reading on each beat — crisp, flat, no halo.
            Group {
                if let bpm {
                    CountUpText(value: Double(bpm),
                                format: { "\(Int($0.rounded()))" },
                                font: StrandFont.rounded(96, weight: .semibold),
                                color: HearthTheme.onSkyRose)
                } else {
                    // A 96pt em-dash reads as a rule, not a placeholder, so the "no reading yet"
                    // state drops to the Effort numeral's size — still the hero slot, clearly empty.
                    Text("—")
                        .font(StrandFont.rounded(56, weight: .semibold))
                        .foregroundStyle(HearthTheme.onSkyRose.opacity(0.45))
                        .frame(height: 96)
                }
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            Text("bpm")
                .font(StrandFont.subhead)
                .foregroundStyle(StrandPalette.onDarkSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Heart rate"))
        .accessibilityValue(Text(bpm.map { "\($0) bpm" } ?? String(localized: "No reading")))
    }

    // MARK: - Effort, secondary
    //
    // The accumulating Effort is the running `ActiveWorkout.liveStrain` (StrainScorer over the
    // captured window), rendered on the user's selected Effort scale (#313): 0–100 native, or
    // rescaled to WHOOP's 0–21, matching the rest of the app's read-outs. Display-only — the captured
    // value stays 0–100. The band word underneath is the SAME word the StrainGauge that used to sit
    // here already drew from the fill fraction (LIGHT / MODERATE / STRENUOUS / HIGH / ALL-OUT); it is
    // a plain restatement of the number, not a new classifier.

    private var effortBlock: some View {
        VStack(spacing: NoopMetrics.space1) {
            Text(UnitFormatter.effortDisplay(liveStrain, scale: effortScale))
                .font(StrandFont.rounded(56, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(StrandPalette.onDarkPrimary)
                .contentTransition(.numericText())
                .animation(StrandMotion.fade, value: liveStrain)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("EFFORT BUILDING")
                .font(StrandFont.overline).tracking(StrandFont.overlineTracking)
                .foregroundStyle(StrandPalette.effortBright)
            Text(Self.effortBandWord(liveStrain))
                .font(StrandFont.subhead)
                .foregroundStyle(StrandPalette.onDarkSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - HR zone rail

    private var zoneBar: some View {
        VStack(alignment: .leading, spacing: NoopMetrics.rowSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text("HR ZONE")
                    .font(StrandFont.overline).tracking(StrandFont.overlineTracking)
                    .foregroundStyle(StrandPalette.onDarkSecondary)
                Spacer(minLength: NoopMetrics.space3)
                if zone >= 1 {
                    Text("Zone \(zone) · \(Self.zoneName(zone))")
                        .font(StrandFont.caption)
                        .foregroundStyle(StrandPalette.onDarkPrimary)
                        .padding(.horizontal, NoopMetrics.space3)
                        .padding(.vertical, NoopMetrics.space1 + 1)
                        // The zone's OWN colour carries the identity; the label stays off-white so the
                        // pill reads at both ends of the sage→maroon ramp.
                        .background(Capsule().fill(StrandPalette.hrZoneColor(zone).opacity(0.32)))
                }
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(1...5, id: \.self) { z in
                    zoneSegment(z)
                }
            }
            if let band = zoneSet.zones.first(where: { $0.number == zone }) {
                Text("Zone \(zone): \(Int(band.lower))-\(Int(band.upper)) bpm (\(Int(band.lowerPct * 100))-\(Int(band.upperPct * 100))% max HR)")
                    .font(StrandFont.footnote).foregroundStyle(StrandPalette.onDarkTertiary)
            } else {
                Text("Warming up. Keep moving to climb into Zone 1.")
                    .font(StrandFont.footnote).foregroundStyle(StrandPalette.onDarkTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One rung of the rail. Inactive zones are a low-opacity tint of THAT zone's own colour (not one
    /// uniform grey), so the ramp still reads as a ramp; the current zone is solid-filled and taller
    /// than its neighbours.
    private func zoneSegment(_ z: Int) -> some View {
        let active = z == zone
        let color = StrandPalette.hrZoneColor(z)
        return RoundedRectangle(cornerRadius: NoopMetrics.space2, style: .continuous)
            .fill(active ? color : color.opacity(0.34))
            .frame(height: active ? 44 : 34)
            .overlay(
                RoundedRectangle(cornerRadius: NoopMetrics.space2, style: .continuous)
                    .strokeBorder(active ? Color.clear : StrandPalette.onDarkPrimary.opacity(0.10),
                                  lineWidth: 1)
            )
            .overlay(
                Text("Z\(z)")
                    .font(StrandFont.captionNumber)
                    .foregroundStyle(active ? Self.labelColor(on: color) : StrandPalette.onDarkSecondary)
            )
            .animation(StrandMotion.fade, value: active)
    }

    // MARK: - Frosted stat strip

    private var statStrip: some View {
        HStack(spacing: 0) {
            strip(String(localized: "AVG"), avgHr > 0 ? "\(avgHr)" : "—", tint: HearthTheme.onSkyRose)
            stripDivider
            strip(String(localized: "PEAK"), peakHr > 0 ? "\(peakHr)" : "—", tint: HearthTheme.onSkyRose)
            stripDivider
            strip(String(localized: "EFFORT"),
                  UnitFormatter.effortDisplay(liveStrain, scale: effortScale),
                  tint: StrandPalette.effortBright)
        }
        .padding(.vertical, NoopMetrics.space4)
        .background(
            RoundedRectangle(cornerRadius: NoopMetrics.cardRadius, style: .continuous)
                .fill(StrandPalette.onDarkPrimary.opacity(0.06))
        )
    }

    private var stripDivider: some View {
        Rectangle()
            .fill(StrandPalette.onDarkPrimary.opacity(0.12))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
    }

    private func strip(_ title: String, _ value: String, tint: Color) -> some View {
        VStack(spacing: NoopMetrics.space1 + 1) {
            Text(title)
                .font(StrandFont.overline).tracking(StrandFont.overlineTracking)
                .foregroundStyle(StrandPalette.onDarkSecondary)
            Text(value)
                .font(StrandFont.number(26))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Floating control bar

    private var controlBar: some View {
        HStack(spacing: 0) {
            // Stop. Destructive, so it still goes through the #517 confirm.
            controlButton("xmark", label: String(localized: "End workout")) {
                showEndConfirm = true
            }
            Group {
                if let start = model.activeWorkout?.start {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text(Self.elapsed(since: start))
                            .font(StrandFont.number(38, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(StrandPalette.onDarkPrimary)
                    }
                } else {
                    Text(Self.elapsed(since: Date()))
                        .font(StrandFont.number(38, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(StrandPalette.onDarkPrimary)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Text("Elapsed time"))
            // Leave the screen WITHOUT stopping the recording. There is no pause/resume in the
            // recorder (AppModel has start/end only), so this slot is a close, not a pause — the
            // workout keeps capturing while the screen is away, and reopening Live/Workouts brings it
            // back. On macOS this is the only way out of the sheet at all.
            controlButton("chevron.down", label: String(localized: "Close, keep recording")) {
                onClose()
            }
        }
        .padding(NoopMetrics.space1)
        .background(Capsule().fill(StrandPalette.textPrimary.opacity(0.72)))
        // The bar floats over the sky's darkest band, so a hairline keeps its edge readable.
        .overlay(Capsule().strokeBorder(StrandPalette.onDarkPrimary.opacity(0.10), lineWidth: 1))
    }

    private func controlButton(_ systemImage: String, label: String,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(StrandFont.headline)
                .foregroundStyle(StrandPalette.onDarkPrimary)
                // 56pt clears the 44pt minimum target with room to spare — this is a control you hit
                // mid-effort, without looking.
                .frame(width: 56, height: 56)
                .background(Circle().fill(StrandPalette.onDarkPrimary.opacity(0.10)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    // MARK: - Helpers

    private static func elapsed(since start: Date) -> String {
        let s = max(0, Int(Date().timeIntervalSince(start)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private static func zoneName(_ zone: Int) -> String {
        switch zone {
        case 1: return String(localized: "Recovery")
        case 2: return String(localized: "Fat burn")
        case 3: return String(localized: "Aerobic")
        case 4: return String(localized: "Threshold")
        case 5: return String(localized: "Maximum")
        default: return ""
        }
    }

    /// The Effort band word, on the SAME thresholds `StrainGauge.strainWord` uses (the gauge that
    /// stood here before this layout drew it under the numeral, `showsLabel` defaulting to true), so
    /// the screen keeps saying exactly what it already said. Computed off the fraction of the stored
    /// 0–100 axis, so it reads identically on the 0–100 and 0–21 display scales. Sentence case here to
    /// match `CoupledView.strainBandWord`, the app's other plain-language restatement of the same
    /// bands.
    private static func effortBandWord(_ strain0to100: Double) -> String {
        switch min(max(strain0to100 / 100, 0), 1) {
        case ..<(6.0 / 21):   return String(localized: "Light")
        case ..<(10.0 / 21):  return String(localized: "Moderate")
        case ..<(14.0 / 21):  return String(localized: "Strenuous")
        case ..<(18.0 / 21):  return String(localized: "High")
        default:              return String(localized: "All-out")
        }
    }

    /// Ink or off-white label for a SOLID zone fill. The Hearth zone ramp runs from a light sage (Z1)
    /// to a dark maroon (Z5), so one fixed label colour fails contrast at one end or the other;
    /// picking by the fill's own relative luminance keeps "Z3" legible wherever the rail lights up.
    private static func labelColor(on fill: Color) -> Color {
        let c = fill.liquidComponents()
        let luma = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
        return luma > 0.55 ? StrandPalette.textPrimary : StrandPalette.onDarkPrimary
    }

    // MARK: - DEBUG screenshot aid
    //
    // The iOS Simulator has no BLE, so a workout started there never receives a heart rate and this
    // hero can only ever be captured in its empty state — which is exactly the state a visual check of
    // the populated layout cannot use. `--demo-workout` substitutes ONE fixed synthetic reading so the
    // full layout can be rendered and screenshotted. Same in-file launch-flag idiom `LiquidTodayView`
    // uses for `--demo-reveal` and `LiquidSyncStatus` for `--demo-sync`; DEBUG-only, stripped from
    // Release, and unreachable without the argument, so no shipped build can show a fabricated number.

    #if DEBUG
    private static let demoRequested = CommandLine.arguments.contains("--demo-workout")
    private static var demoBPM: Int? { demoRequested ? 152 : nil }
    private static var demoAvgHr: Int? { demoRequested ? 138 : nil }
    private static var demoPeakHr: Int? { demoRequested ? 164 : nil }
    /// 54.3 on the stored 0–100 Effort axis — 11.4 once rescaled to the 0–21 display scale.
    private static var demoStrain: Double? { demoRequested ? 54.3 : nil }
    #else
    private static var demoBPM: Int? { nil }
    private static var demoAvgHr: Int? { nil }
    private static var demoPeakHr: Int? { nil }
    private static var demoStrain: Double? { nil }
    #endif
}

// MARK: - Live-observing leaf (scroll-stutter isolation)

/// Additive readout for a connected standard fitness sensor (a footpod / bike speed-cadence sensor /
/// power meter) feeding RSC/CSC/CPS ALONGSIDE heart rate. Only the fields the sensor actually sent
/// render — each metric is dropped when its value is absent, and the WHOLE block (panel + entrance stagger)
/// is hidden when nothing is present (`live.hasSensorMetrics`), so a plain HR-only workout looks exactly
/// as before. Honest units: speed km/h, cadence per-minute (steps for running / rpm for cycling), power
/// watts. Nothing here touches HR / zone / effort.
///
/// This is a standalone leaf that owns its OWN `@EnvironmentObject live` (the parent `LiveWorkoutView`
/// no longer observes `LiveState`), so an incoming sensor / R-R packet re-renders only this row, not the
/// HR hero / effort read-out / zone rail above.
private struct SensorRowIfPresent: View {
    @EnvironmentObject private var live: LiveState

    var body: some View {
        if live.hasSensorMetrics {
            let speed = LiveState.formatSpeedKmh(live.sensorSpeedKmh)
            let cadence = LiveState.formatCadence(live.sensorCadence)
            let power = LiveState.formatPowerWatts(live.sensorPowerWatts)
            HStack(spacing: 0) {
                if let speed { stat(String(localized: "SPEED"), "\(speed) km/h") }
                if let cadence {
                    if speed != nil { divider }
                    stat(String(localized: "CADENCE"), "\(cadence)/min")
                }
                if let power {
                    if speed != nil || cadence != nil { divider }
                    stat(String(localized: "POWER"), "\(power) W")
                }
            }
            .padding(.vertical, NoopMetrics.space4)
            .background(
                RoundedRectangle(cornerRadius: NoopMetrics.cardRadius, style: .continuous)
                    .fill(StrandPalette.onDarkPrimary.opacity(0.06))
            )
            .staggeredAppear(index: 5)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(StrandPalette.onDarkPrimary.opacity(0.12))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
    }

    /// The same frosted-strip cell as `LiveWorkoutView.strip`, so the sensor row reads as a second
    /// course of the stat strip above it rather than a competing card.
    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: NoopMetrics.space1 + 1) {
            Text(title)
                .font(StrandFont.overline).tracking(StrandFont.overlineTracking)
                .foregroundStyle(StrandPalette.onDarkSecondary)
            Text(value)
                .font(StrandFont.number(22))
                .monospacedDigit()
                .foregroundStyle(StrandPalette.effortBright)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// Live GPS distance + average pace on the active-workout screen, for distance sports (#1195). The main
/// gap this closes: the recorder already computes and publishes `distanceM` / `paceSecPerKm` on every
/// accepted fix, but they were only ever shown in the post-workout detail view — never live.
///
/// A standalone leaf that owns its OWN `@ObservedObject` on the recorder (the parent `LiveWorkoutView`
/// does not observe it), so a GPS fix re-renders only this row — not the HR hero / effort read-out
/// above, the same scroll-stutter isolation as `SensorRowIfPresent`. Self-gates to nothing until the
/// first accepted fix, so a denied-permission or GPS-less (Mac) session shows no empty row. Mirrors
/// Android's gated distance/pace row in `LiveWorkoutScreen`. Styled as the same frosted-strip cell as
/// the sensor row above it, matching the hero column's flat aesthetic rather than the old card chrome.
private struct DistancePaceRowIfPresent: View {
    @ObservedObject var recorder: GpsWorkoutRecorder
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue
    private var unitSystem: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    var body: some View {
        // `isRecording` is essential, not just `pointCount > 0`: the recorder is a single long-lived
        // object and `stop()` leaves `pointCount`/`distanceM` intact (only `start()` resets them, and it
        // runs solely for distance sports). Without the `isRecording` guard a non-GPS workout started
        // after a GPS one would show the previous session's stale distance. Together they mean "a GPS
        // recording is live AND has at least one accepted fix" — the Android `gpsEnabled && track` twin.
        if recorder.isRecording, recorder.pointCount > 0 {
            HStack(spacing: 0) {
                // "Distance"/"Pace" are already localized (reused from the detail view); uppercased for
                // the caps stat grid, exactly as the detail route stats do.
                stat(String(localized: "Distance").uppercased(),
                     UnitFormatter.distanceFromMeters(recorder.distanceM, system: unitSystem))
                divider
                stat(String(localized: "Pace").uppercased(),
                     UnitFormatter.paceFromSecPerKm(recorder.paceSecPerKm, system: unitSystem))
            }
            .padding(.vertical, NoopMetrics.space4)
            .background(
                RoundedRectangle(cornerRadius: NoopMetrics.cardRadius, style: .continuous)
                    .fill(StrandPalette.onDarkPrimary.opacity(0.06))
            )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(StrandPalette.onDarkPrimary.opacity(0.12))
            .frame(width: 1)
            .frame(maxHeight: .infinity)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: NoopMetrics.space1 + 1) {
            Text(title)
                .font(StrandFont.overline).tracking(StrandFont.overlineTracking)
                .foregroundStyle(StrandPalette.onDarkSecondary)
            Text(value)
                .font(StrandFont.number(22))
                .monospacedDigit()
                .foregroundStyle(StrandPalette.effortBright)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
