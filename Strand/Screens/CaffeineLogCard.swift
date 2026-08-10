import SwiftUI
import StrandDesign

/// Caffeine window (#526) — log a caffeine intake (time + OPTIONAL mg) and see a plain on-device
/// "still active" hint. OPT-IN, manual-first: nothing shows until the user logs an intake, and the
/// estimate is clearly framed as a rough guide from a ~5–6 h half-life decay, never a measurement or a
/// health claim. Reuses the journal logging patterns (UserDefaults-backed store, pill controls, NoopCard).
///
/// Honesty is enforced in the model (`CaffeineDecay` / `CaffeineLogStore`): an unknown amount stays
/// unknown (we never invent mg), the active hint covers the dose-unknown case in words, and the copy
/// states it's an estimate from what was logged.
struct CaffeineLogCard: View {
    /// The shared UserDefaults-backed store (#949). Shared rather than owned here so the Apple Health
    /// import and this card write through the same instance — see `CaffeineLogStore.shared`.
    @ObservedObject private var store = CaffeineLogStore.shared

    /// Drives a live recompute of the estimate while the card is on screen (the decay is time-based).
    @State private var tick = Date()
    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    @State private var mgDraft = ""
    /// "How long ago" quick options for logging — hours back from now.
    private let quickHoursAgo: [Int] = [0, 1, 2, 3]

    // PR#566 (mvanhorn) — caffeine cutoff window + late-intake nudge. OPT-IN (default OFF, manual-first):
    // when enabled, NOOP works back from the user's bedtime by the dose's decay lead and flags any logged
    // intake that lands past that cutoff, with a calm inline nudge. Keys MIRROR the Android prefs
    // (KEY_CAFFEINE_CUTOFF / KEY_CAFFEINE_BEDTIME_MIN, default 23:00) so a layout reads the same on both.
    @AppStorage(Self.cutoffEnabledKey) private var cutoffEnabled = false
    @AppStorage(Self.bedtimeMinutesKey) private var bedtimeMinutes = 23 * 60
    static let cutoffEnabledKey = "noop.caffeine.cutoffNudge"
    static let bedtimeMinutesKey = "noop.caffeine.bedtimeMinutes"

    /// Whether the "Add a drink" composer (amount + how-long-ago pills) is expanded. Collapsed by
    /// default so the card reads as the mockup's list — rows, then one add affordance — instead of
    /// leading with a form.
    @State private var composerOpen = false

    var body: some View {
        // Hearth "Group" card: this is a LIST (an estimate, the cutoff setting, each logged intake),
        // and the mockup's rule for anything list-shaped is one divided GroupCard whose LAST row is the
        // add affordance — not a form-first tinted panel. `GroupCard` draws the hairline between rows
        // itself, so the explicit Dividers are gone.
        VStack(alignment: .leading, spacing: NoopMetrics.gap) {
            SectionHeader("Caffeine", overline: "Log")
            GroupCard("Logged today") {
                activeHint

                // PR#566 — the late-intake nudge sits right under the active hint when the cutoff is on
                // and a logged intake is past it, so the timing warning is the first thing read. The
                // condition is hoisted to the card's builder (rather than living inside the row) so an
                // inapplicable nudge contributes no child, and therefore no stray hairline.
                if cutoffEnabled, latePastCutoffCount > 0 {
                    lateIntakeNudgeRow
                }

                cutoffSection

                ForEach(store.intakes) { intake in
                    intakeRow(intake)
                }

                // The add affordance closes the list (mockup: "Add a drink →" is a normal row with
                // accent-coloured text, not a separate button). Expanding it reveals the composer
                // beneath, so the row itself stays the last thing in the list.
                VStack(alignment: .leading, spacing: 12) {
                    addDrinkRow
                    if composerOpen { composer }
                }
                .padding(.vertical, composerOpen ? 4 : 0)
            }
            Text("Log a coffee, tea, or energy drink and NOOP shows a rough estimate of how much may still be active. It's a guide based on a typical 5 to 6 hour half-life, not a measurement.")
                .font(StrandFont.footnote)
                .foregroundStyle(StrandPalette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onReceive(ticker) { tick = $0 }
    }

    // MARK: - Row chrome
    //
    // A `GroupRow`-shaped row for content that is an ALREADY-LOCALIZED runtime String (the estimate
    // sentence, an intake's "7:40 · 130 mg" label). `GroupRow` takes a `LocalizedStringKey`, which would
    // send those through a second, always-missing table lookup, so these rows are laid out here to the
    // same metrics (14pt vertical, explicit hit shape) instead.
    @ViewBuilder
    private func logRow<Trailing: View>(title: String, titleColor: Color = StrandPalette.textPrimary,
                                        subtitle: String? = nil,
                                        @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title)
                    .font(StrandFont.body)
                    .foregroundStyle(titleColor)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(verbatim: subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(StrandPalette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    // MARK: - Add affordance + composer

    private var addDrinkRow: some View {
        Button { composerOpen.toggle() } label: {
            HStack(spacing: 12) {
                Text("Add a drink")
                    .font(StrandFont.body)
                    .foregroundStyle(StrandPalette.accent)
                Spacer(minLength: 8)
                Image(systemName: composerOpen ? "chevron.down" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StrandPalette.textTertiary.opacity(0.7))
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a caffeine drink")
        .accessibilityAddTraits(composerOpen ? [.isSelected] : [])
    }

    /// The logging controls. Unchanged behaviour: an OPTIONAL amount (blank stays unknown — we never
    /// invent a number) plus "now / N hours ago".
    @ViewBuilder private var composer: some View {
        HStack {
            TextField("Amount in mg (optional)", text: $mgDraft)
                .textFieldStyle(.roundedBorder)
            #if os(iOS)
                .keyboardType(.numberPad)
            #endif
            Text("mg")
                .font(StrandFont.footnote)
                .foregroundStyle(StrandPalette.textTertiary)
        }
        HStack {
            Text("Had it")
                .font(StrandFont.footnote)
                .foregroundStyle(StrandPalette.textSecondary)
            Spacer()
            ForEach(quickHoursAgo, id: \.self) { h in
                logPill(h == 0 ? "Now" : "\(h)h ago", hoursAgo: h)
            }
        }
    }

    // MARK: - Cutoff window (PR#566) — bedtime + late-intake nudge

    /// The bedtime + cutoff controls: a toggle, and (when on) a bedtime picker plus the derived "stop after"
    /// time. OFF by default — nothing here surfaces or nags until the user opts in. The cutoff time itself is
    /// computed from the dose-decay lead (`CaffeineDecay.cutoffMinutesSinceMidnight`), so it's never a magic
    /// number and matches the "still active" math.
    @ViewBuilder private var cutoffSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row metrics match `GroupRow`, but written out: `GroupRow`'s subtitle is single-line, and
            // this one carries the feature's honesty caveat in full ("a timing guide … not a
            // measurement"), which must not be truncated to fit a row.
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cutoff before bed")
                        .font(StrandFont.body)
                        .foregroundStyle(StrandPalette.textPrimary)
                    Text("Warn me when I log caffeine too close to bedtime. A timing guide from your own bedtime, not a measurement.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(StrandPalette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: $cutoffEnabled)
                    .labelsHidden().toggleStyle(.switch).tint(StrandPalette.accent)
                    .accessibilityLabel("Warn me about caffeine close to bedtime")
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            if cutoffEnabled {
                HStack {
                    Text("Bedtime")
                        .font(StrandFont.footnote)
                        .foregroundStyle(StrandPalette.textSecondary)
                    Spacer()
                    DatePicker("", selection: bedtimeBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .accessibilityLabel("Bedtime")
                }
                Text("Stop caffeine after about \(cutoffTimeLabel) to keep most of it cleared by \(timeLabel(bedtimeMinutes)).")
                    .font(StrandFont.footnote)
                    .foregroundStyle(StrandPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 12)
            }
        }
    }

    /// The late-intake nudge — shown only when the cutoff is ON and at least one logged intake falls
    /// past the cutoff for the user's bedtime (the caller gates it; see the card body). Honest: it warns
    /// about TIMING ("may keep you up"), never a health claim, and it disappears the moment no logged
    /// intake is past cutoff.
    private var lateIntakeNudgeRow: some View {
        logRow(title: lateNudgeText, titleColor: StrandPalette.statusWarning) {
            Image(systemName: "moon.zzz")
                .font(StrandFont.body)
                .foregroundStyle(StrandPalette.statusWarning)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    /// Count of logged intakes whose local time-of-day is past the bedtime cutoff. Uses the shared decay
    /// model's `isPastCutoff` so the UI and the cutoff math can't drift. Each intake's wall-clock minute is
    /// compared against the cutoff derived from the user's bedtime.
    private var latePastCutoffCount: Int {
        store.intakes.filter { intake in
            CaffeineDecay.isPastCutoff(intakeMinutes: minutesSinceMidnight(intake.at),
                                       bedtimeMinutes: bedtimeMinutes)
        }.count
    }

    private var lateNudgeText: String {
        let n = latePastCutoffCount
        // Whole-phrase variants per count so translators see complete sentences (never a stitched lead).
        return n == 1
            ? String(localized: "A logged caffeine is past your bedtime cutoff. It may still be on board and keep you up. Just a timing heads-up.")
            : String(localized: "\(n) logged caffeines are past your bedtime cutoff. They may still be on board and keep you up. Just a timing heads-up.")
    }

    /// The cutoff time-of-day label, derived from bedtime minus the dose-decay lead (shared model).
    private var cutoffTimeLabel: String {
        timeLabel(CaffeineDecay.cutoffMinutesSinceMidnight(bedtimeMinutes: bedtimeMinutes))
    }

    /// Local minutes-since-midnight for a logged intake's wall-clock time.
    private func minutesSinceMidnight(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Bridges the minutes-since-midnight bedtime pref to the DatePicker's Date.
    private var bedtimeBinding: Binding<Date> {
        Binding(
            get: {
                var c = DateComponents()
                c.hour = bedtimeMinutes / 60
                c.minute = bedtimeMinutes % 60
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                bedtimeMinutes = min(max((c.hour ?? 23) * 60 + (c.minute ?? 0), 0), 24 * 60 - 1)
            }
        )
    }

    private func timeLabel(_ minutes: Int) -> String {
        var c = DateComponents()
        c.hour = minutes / 60
        c.minute = minutes % 60
        let date = Calendar.current.date(from: c) ?? Date()
        return Self.cutoffTimeFormatter.string(from: date)
    }

    private static let cutoffTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    // MARK: - Active hint

    /// The "caffeine still active" readout. Computed from the logged intakes via the decay model. Shows
    /// an mg estimate only when at least one active intake had a known amount; otherwise it's worded
    /// without a number (honest: we don't fabricate a dose). Renders a calm "all clear" line when nothing
    /// is active so the card always reads as live, never blank.
    @ViewBuilder private var activeHint: some View {
        let est = store.estimate()
        if est.hasActive {
            logRow(title: activeTitle(est), subtitle: activeDetail(est)) { EmptyView() }
                .accessibilityElement(children: .combine)
        } else {
            logRow(title: store.intakes.isEmpty
                   ? String(localized: "No caffeine logged. Log an intake to see an estimate.")
                   : String(localized: "Estimated mostly cleared. Nothing logged is likely still active."),
                   titleColor: StrandPalette.textTertiary) { EmptyView() }
                .accessibilityElement(children: .combine)
        }
    }

    private func activeTitle(_ est: CaffeineActiveEstimate) -> String {
        if let mg = est.totalRemainingMg {
            return String(localized: "About \(Int(mg.rounded())) mg may still be active")
        }
        return String(localized: "Caffeine may still be active")
    }

    /// Whole-phrase variants per combination (recent-intake line and/or multi-intake line) so
    /// translators always see a complete sentence rather than joined fragments.
    private func activeDetail(_ est: CaffeineActiveEstimate) -> String {
        let recent = est.hoursSinceMostRecentActive.map(hoursLabel)
        let count = est.activeIntakeCount
        switch (recent, count > 1) {
        case (let r?, true):
            return String(localized: "most recent intake about \(r) ago · \(count) intakes still in the estimate. Rough guide only, based on what you logged.")
        case (let r?, false):
            return String(localized: "most recent intake about \(r) ago. Rough guide only, based on what you logged.")
        case (nil, true):
            return String(localized: "\(count) intakes still in the estimate. Rough guide only, based on what you logged.")
        case (nil, false):
            return String(localized: "Rough guide only, based on what you logged.")
        }
    }

    private func hoursLabel(_ hrs: Double) -> String {
        if hrs < 1 { return String(localized: "under an hour") }
        let rounded = Int(hrs.rounded())
        return rounded == 1 ? String(localized: "1 hour") : String(localized: "\(rounded) hours")
    }

    // MARK: - Logged list

    private func intakeRow(_ intake: CaffeineIntake) -> some View {
        logRow(title: intakeLabel(intake)) {
            // No remove control on an imported intake (#949): the next sync re-reads the same window
            // from Apple Health and would bring it straight back, so offering the button would be
            // offering something NOOP cannot honour. Remove it where it was logged.
            if intake.isImported {
                Text("Apple Health")
                    .font(StrandFont.caption)
                    .foregroundStyle(StrandPalette.textTertiary)
            } else {
                Button {
                    store.remove(intake.id)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(StrandFont.body)
                        .foregroundStyle(StrandPalette.statusCritical)
                        // 44pt hit target around the small glyph, matching the other row controls.
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove caffeine intake at \(Self.timeFormatter.string(from: intake.at))")
            }
        }
    }

    private func intakeLabel(_ intake: CaffeineIntake) -> String {
        let time = Self.timeFormatter.string(from: intake.at)
        if let mg = intake.mg {
            return String(localized: "\(time) · \(Int(mg.rounded())) mg")
        }
        return String(localized: "\(time) · amount not logged")
    }

    // MARK: - Controls

    private func logPill(_ label: LocalizedStringKey, hoursAgo: Int) -> some View {
        pillButton(label, selected: false) {
            let mg = Double(mgDraft.trimmingCharacters(in: .whitespaces))   // nil if blank/invalid
            let at = Calendar.current.date(byAdding: .hour, value: -hoursAgo, to: tick) ?? tick
            store.log(at: at, mg: mg)
            mgDraft = ""
        }
    }

    private func pillButton(_ label: LocalizedStringKey, selected: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(StrandFont.footnote)
                .foregroundStyle(selected ? StrandPalette.surfaceBase : StrandPalette.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(selected ? StrandPalette.accent : StrandPalette.surfaceInset, in: Capsule())
                .overlay(Capsule().stroke(selected ? StrandPalette.accent : StrandPalette.hairline,
                                          lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}
