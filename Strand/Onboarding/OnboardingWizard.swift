import SwiftUI
import UniformTypeIdentifiers
import StrandDesign
import WhoopStore
import UserNotifications

// MARK: - OnboardingWizard
//
// A full-screen, paged onboarding + pairing flow for NOOP, in the Hearth visual system.
//
// The shell is the mockup's "thread shell": twelve steps over ONE sky, with progress shown as a
// 2pt hairline thread at the very top that fills as you advance — no counter, no chrome. Each step
// is one of two page shapes:
//
//   • a MOMENT page (welcome / bonded / done) — full-bleed sky, nothing above the thread, the
//     statement set in the serif voice at the bottom, and a LIGHT cream pill CTA (a dark ink pill
//     would disappear into the sky's dark lower half);
//   • a SHEET page (everything else) — a sky header carrying the kicker + serif statement, then a
//     cream sheet (radius 32 top) that the content sits on, with a DARK INK pill CTA pinned to the
//     bottom of that sheet, matching every other Hearth page once content is on paper.
//
// Steps (the enum below is the source of truth; the mockup's example frames map 1:1 onto it):
//  1 Welcome           — NOOP + "all your data, none of the cloud"   [moment]
//  2 What it does      — 3 calm value cards
//  3 Bluetooth priming — explain BEFORE the OS prompt
//  4 Wear & wake       — put your strap on, make sure it's charged
//  5 Scan              — radar rings; auto-scans, Scan retries via model.scan()
//  6 Bonding           — the one moment the sky shifts green         [moment]
//  7 Profile           — age / sex / weight / height bound to ProfileStore
//  8 Import (optional) — WHOOP / Apple Health import from the wizard
//  9 Notifications     — the OS prompt fires on LEAVING, not entering
// 10 Appearance        — System / Light / Dark
// 11 Done              — "Your thread starts here."                  [moment]
//
// Presentation is wired centrally; this view only calls onFinished() when complete.

public struct OnboardingWizard: View {

    /// Called when the user finishes (or skips to the end of) onboarding.
    public var onFinished: () -> Void

    public init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    // NOTE: the root deliberately does NOT observe the fast-updating model/live/profile
    // env objects — doing so re-rendered the whole animated wizard on every HR tick and
    // caused flicker. Child steps observe what they need; a hidden BondWatcher (below)
    // handles the bond→celebration transition without re-rendering the root.

    private enum Step: Int, CaseIterable {
        case welcome, what, expectations, bluetooth, wear, scan, bonded, profile, importData, notifications, appearance, done

        var isFirst: Bool { self == .welcome }
        var isLast: Bool { self == .done }

        /// Moment pages sit full-bleed on the sky with NO chrome above the thread (the mockup's own
        /// caption for step 1) — so no Back row, no sheet, and a light cream CTA.
        var isMoment: Bool { self == .welcome || self == .bonded || self == .done }
    }

    @State private var step: Step = OnboardingWizard.initialStep
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        ZStack {
            sky

            VStack(spacing: 0) {
                // The thread: a hairline that fills across the flow. No counter — 1a, not 1b.
                ThreadProgress(progress: progress, complete: step.isLast)
                    .padding(.horizontal, 30)
                    .padding(.top, 14)

                if !step.isMoment {
                    backRow
                        .padding(.horizontal, 26)
                        .padding(.top, 12)
                }

                page
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(stepTransition)
                    .id(step)                       // re-runs the transition per step
            }
            // A phone-shaped column even on a wide Mac window / iPad — the sky fills the rest, so the
            // flow reads as the same narrative at every size instead of a 1100pt-wide cream sheet.
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Isolated live observation — a hidden watcher slides Scan → celebration on bond
        // without subscribing the whole wizard to per-tick updates.
        .background(BondWatcher(onBonded: handleBond))
    }

    private func handleBond() {
        if step == .scan { withAnimation(StrandMotion.hero) { step = .bonded } }
    }

    // MARK: Sky
    //
    // One sky for the flow, with two bespoke moments cross-fading over it: green when the strap
    // bonds, and the warmer "sun overhead" gradient on the closing frame. All three are STATIC
    // canvases (no TimelineView) layered at fixed opacity, so the cross-fade is a cheap opacity
    // animation rather than a re-render, and none of them touches the global day-cycle sky.

    private var sky: some View {
        ZStack {
            OnboardingSkyLayer(stop: HearthTheme.onboardingSky)
            OnboardingSkyLayer(stop: HearthTheme.onboardingBondedSky)
                .opacity(step == .bonded ? 1 : 0)
            OnboardingSkyLayer(stop: HearthTheme.onboardingDoneSky)
                .opacity(step == .done ? 1 : 0)
        }
        .animation(StrandMotion.hero, value: step)
        .ignoresSafeArea()
    }

    // MARK: Back

    @ViewBuilder
    private var backRow: some View {
        HStack {
            Button(action: back) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Back")
                        .font(StrandFont.subhead)
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 4)
                .frame(height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .opacity(step.isFirst ? 0 : 1)
            .disabled(step.isFirst)
            Spacer(minLength: 0)
        }
    }

    /// The thread's fill fraction. Matches the mockup's own per-step percentages (step 1 = 8%,
    /// 3 = 25%, 6 = 50%, 12 = 100%): steps COMPLETED-through-current over the total, so the very
    /// first screen already shows a sliver of thread and the last shows it whole.
    private var progress: Double {
        Double(step.rawValue + 1) / Double(Step.allCases.count)
    }

    // MARK: The pages

    @ViewBuilder
    private var page: some View {
        switch step {
        case .welcome:
            MomentPage(kicker: String(localized: "NOOP"),
                       statement: String(localized: "all your data, none of the cloud"),
                       bodyCopy: String(localized: "A private window into your recovery, sleep and strain. Read straight from your strap, kept only on \(Platform.deviceNounPhrase)."),
                       cta: cta)
        case .what:
            WhatItDoesStep(cta: cta)
        case .expectations:
            ExpectationsStep(cta: cta)
        case .bluetooth:
            BluetoothStep(cta: cta)
        case .wear:
            WearStep(cta: cta)
        case .scan:
            ScanStep(cta: cta)
        case .bonded:
            BondedStep(cta: cta)
        case .profile:
            ProfileStep(cta: cta)
        case .importData:
            ImportStep(cta: cta)
        case .notifications:
            NotificationsStep(cta: cta)
        case .appearance:
            AppearanceStep(cta: cta)
        case .done:
            MomentPage(statement: String(localized: "Your thread starts here."),
                       bodyCopy: String(localized: "Every beat, every night, every day, woven into one quiet picture of you. Welcome to NOOP."),
                       cta: cta)
        }
    }

    private var cta: OnboardingCTA {
        OnboardingCTA(title: ctaTitle, icon: ctaIcon, light: step.isMoment, action: primaryAction)
    }

    private var ctaTitle: String {
        switch step {
        case .welcome:    return String(localized: "Get Started")
        case .what:       return String(localized: "Continue")
        case .expectations: return String(localized: "I understand")
        case .bluetooth:  return String(localized: "Continue")
        case .wear:       return String(localized: "I'm wearing it")
        case .scan:       return String(localized: "Continue")
        case .bonded:     return String(localized: "Continue")
        case .profile:    return String(localized: "Save & Continue")
        case .importData: return String(localized: "Continue")
        case .notifications: return String(localized: "Continue")
        case .appearance: return String(localized: "Continue")
        case .done:       return String(localized: "Enter NOOP")
        }
    }

    private var ctaIcon: String? {
        switch step {
        case .done: return "arrow.right"
        default:    return nil
        }
    }

    private func primaryAction() {
        if step.isLast {
            onFinished()
        } else {
            advance()
        }
    }

    // MARK: Navigation

    /// Leaving the Notifications step is the one point in onboarding where we actually ask the OS for
    /// notification permission — everything before this only explained why (the `NotificationsStep`
    /// card). Without this, NOOP never showed up under Settings → Notifications at all unless a user
    /// later found and enabled one of the opt-in automations (wind-down, battery, illness) buried in
    /// More → Alarms/Automations, each of which lazily requests on its own toggle. Mirrors the Android
    /// onboarding's `OnboardingPage.Notifications` step (`OnboardingScreen.kt`): request only if not
    /// already determined (so a re-run/upgrade doesn't re-prompt), and advance once the OS dialog is
    /// dismissed either way — the per-feature toggles still handle a later denial on their own.
    private func advance() {
        guard step != .notifications else {
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                guard settings.authorizationStatus == .notDetermined else {
                    Task { @MainActor in advanceStep() }
                    return
                }
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
                    Task { @MainActor in advanceStep() }
                }
            }
            return
        }
        advanceStep()
    }

    private func advanceStep() {
        guard let next = Step(rawValue: step.rawValue + 1) else { onFinished(); return }
        withAnimation(StrandMotion.gentle) { step = next }
    }

    private func back() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        withAnimation(StrandMotion.gentle) { step = prev }
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    /// Onboarding is normally reachable only on a fresh install. In DEBUG, `-noop.onboardingStep N`
    /// (1-based, as the steps are numbered in the header comment) opens the wizard directly on one
    /// step so a simulator run can verify/screenshot any page — including `bonded`, which otherwise
    /// needs a real strap. Release always starts at step 1.
    private static var initialStep: Step {
        #if DEBUG
        let n = UserDefaults.standard.integer(forKey: "noop.onboardingStep")
        if n > 0, let s = Step(rawValue: n - 1) { return s }
        #endif
        return .welcome
    }
}

/// Hidden, isolated observer — re-renders on live updates (it's just Color.clear, so no
/// visible cost) and fires `onBonded` when the strap bonds, keeping the main wizard body
/// out of the per-tick re-render path that caused flicker.
private struct BondWatcher: View {
    @EnvironmentObject private var live: LiveState
    let onBonded: () -> Void
    var body: some View {
        Color.clear.onChangeCompat(of: live.bonded) { newValue in if newValue { onBonded() } }
    }
}

// MARK: - Page shells

/// The forward action for a step, resolved by the root (which owns the step machine) and handed to
/// the page so the pill can sit where that page's layout needs it — bottom of the sky on a moment
/// page, bottom of the cream sheet everywhere else.
private struct OnboardingCTA {
    let title: String
    var icon: String? = nil
    /// Light cream pill (on the sky) vs dark ink pill (on the cream sheet).
    var light: Bool = false
    let action: () -> Void
}

/// A MOMENT page: full-bleed sky, statement + copy pinned to the bottom, light CTA. No sheet, no
/// cards — the mockup reserves this shape for the three frames that are a moment rather than a task.
private struct MomentPage: View {
    var kicker: String? = nil
    let statement: String
    var bodyCopy: String? = nil
    let cta: OnboardingCTA

    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer(minLength: 0)
            if let kicker {
                Text(kicker).skyKicker()
            }
            Text(statement).skyStatement(size: 38)
            if let bodyCopy {
                Text(bodyCopy).skyBody()
            }
            OnboardingPillButton(cta: cta)
                .padding(.top, 14)
        }
        .opacity(appear ? 1 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 30)
        .padding(.bottom, 40)
        .onAppear { withAnimation(StrandMotion.hero) { appear = true } }
    }
}

/// A SHEET page: the sky header (kicker + serif statement + optional supporting line, or a bespoke
/// header like the scan radar), then the cream sheet the content scrolls in, with the ink CTA pinned
/// to the sheet's bottom edge so it never scrolls out of reach on a long step (Profile, Import).
private struct SheetPage<Header: View, Content: View>: View {
    let cta: OnboardingCTA
    @ViewBuilder var header: () -> Header
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            header()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 30)
                .padding(.top, 16)
                .padding(.bottom, 28)

            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        content()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 16)
                }
                OnboardingPillButton(cta: cta)
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // The paper runs off the bottom of the screen (the mockup's sheet has no bottom edge).
            // Only the BACKGROUND ignores the safe area — the CTA keeps its inset, so the pill never
            // sits under the home indicator.
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32, style: .continuous)
                    .fill(StrandPalette.surfaceBase)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }
}

/// The standard sky header: kicker (the step's name, small caps) + the serif voice statement +
/// optional supporting line — the same anatomy every Hearth page header uses (`ScreenScaffold`).
private struct SkyHeader: View {
    let kicker: String
    let statement: String
    var bodyCopy: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(kicker).skyKicker()
            Text(statement).skyStatement(size: 30)
            if let bodyCopy {
                Text(bodyCopy).skyBody()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension Text {
    /// The quiet all-caps overline that names the step, on the sky.
    func skyKicker() -> some View {
        self.font(StrandFont.overlineScaled(10))
            .tracking(2.4)
            .textCase(.uppercase)
            .foregroundStyle(.white.opacity(0.6))
    }

    /// The one editorial line per page, in the serif voice.
    func skyStatement(size: CGFloat) -> some View {
        self.font(StrandFont.voice(size, relativeTo: .title))
            .lineSpacing(3)
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Supporting copy under the statement, still on the sky.
    func skyBody() -> some View {
        self.font(StrandFont.body)
            .lineSpacing(3)
            .foregroundStyle(.white.opacity(0.78))
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Buttons

/// The wizard's one CTA shape: a full-width pill. Cream on the sky (a dark ink pill vanishes into the
/// sky's dark lower half), ink once the content has moved onto the cream sheet — the mockup switches
/// per page, so this follows `cta.light` rather than standardising on one.
private struct OnboardingPillButton: View {
    let cta: OnboardingCTA

    var body: some View {
        Button(action: cta.action) {
            HStack(spacing: 8) {
                Text(cta.title)
                if let icon = cta.icon {
                    Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                }
            }
            .font(StrandFont.body.weight(.semibold))
            .foregroundStyle(cta.light ? StrandPalette.textPrimary : NoopButtonPalette.primaryLabel)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Capsule().fill(cta.light ? StrandPalette.surfaceRaised : NoopButtonPalette.primaryFill))
            .contentShape(Capsule())
        }
        .buttonStyle(StrandPressableButtonStyle(cornerRadius: 27))
    }
}

// MARK: - Sheet content pieces

/// The mockup's plain "Group"-style card in its simplest form: a kicker over a paragraph. Used
/// wherever a step is explaining rather than listing.
private struct NoteCard: View {
    let kicker: String
    let text: String

    var body: some View {
        StrandCard(padding: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(kicker).strandOverline()
                Text(text)
                    .font(StrandFont.subhead)
                    .lineSpacing(2)
                    .foregroundStyle(StrandPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A clay Alert card with the same kicker/paragraph anatomy — for the one flagged thing on a page.
private struct FlagCard: View {
    var kicker: String? = nil
    let text: String

    var body: some View {
        AlertCard {
            VStack(alignment: .leading, spacing: 10) {
                if let kicker { Text(kicker).strandOverline() }
                Text(text)
                    .font(StrandFont.subhead)
                    .lineSpacing(2)
                    .foregroundStyle(StrandPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A sage Insight/conclusion card — "the only place the app draws a conclusion".
private struct TakeawayCard: View {
    var kicker: String? = nil
    let text: String

    var body: some View {
        ConclusionCard {
            VStack(alignment: .leading, spacing: 10) {
                if let kicker { Text(kicker).strandOverline() }
                Text(text)
                    .font(StrandFont.subhead)
                    .lineSpacing(2)
                    .foregroundStyle(StrandPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A card of checklines (the "here's what to do" list) — the checkline copy is long-form, so it can't
/// use `GroupRow`, which is a single-line list row.
private struct ChecklistCard: View {
    let lines: [String]

    var body: some View {
        StrandCard(padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(lines, id: \.self) { Checkline(text: $0) }
            }
        }
    }
}

/// A footnote on the cream sheet — the small print a step needs but shouldn't shout.
private struct SheetFootnote: View {
    let text: String
    var body: some View {
        Text(text)
            .font(StrandFont.footnote)
            .foregroundStyle(StrandPalette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }
}

// MARK: - Step 2 · What it does

private struct WhatItDoesStep: View {
    let cta: OnboardingCTA

    private struct Slide: Identifiable {
        let id = UUID()
        let title: String
        let body: String
    }

    private let slides: [Slide] = [
        .init(title: String(localized: "See recovery, beautifully"),
              body: String(localized: "A signature ring distils HRV, resting heart rate and sleep into one calm read on whether to push or rest.")),
        .init(title: String(localized: "Watch your heart, live"),
              body: String(localized: "Connect a WHOOP, a heart-rate strap or a gym machine and watch each beat in real time: heart rate, variability and zones as they happen. Already have history elsewhere? Import it from WHOOP, Apple Health, Oura, Fitbit or Garmin.")),
    ]

    var body: some View {
        SheetPage(cta: cta) {
            SkyHeader(kicker: String(localized: "What NOOP does"),
                      statement: String(localized: "Three quiet promises."))
        } content: {
            ForEach(slides) { slide in
                NoteCard(kicker: slide.title, text: slide.body)
            }
            // The third promise is the one the whole app is built around, so it lands as the sage
            // takeaway rather than a third identical paper card.
            TakeawayCard(kicker: String(localized: "Own your data, offline"),
                         text: String(localized: "Everything lives on \(Platform.deviceNounPhrase). No account, no sync, no cloud. Your thread is yours alone."))
        }
    }
}

// MARK: - Step 3 · What to expect (independent / experimental / 5-MG framing)

private struct ExpectationsStep: View {
    let cta: OnboardingCTA

    var body: some View {
        SheetPage(cta: cta) {
            SkyHeader(kicker: String(localized: "What to expect"),
                      statement: String(localized: "A few honest words, so nothing's a surprise."))
        } content: {
            // Card kind is positional, matching the mockup's own composition: plain paper cards, ONE
            // clay Alert (the 5.0/MG experimental caveat, which is the flagged thing on this page),
            // and the sage takeaway CLOSING the page. If the list in AppChangelog changes shape this
            // degrades to plain cards rather than mis-flagging something.
            let items = AppChangelog.expectations
            let last = items.count - 1
            ForEach(Array(items.enumerated()), id: \.element.id) { index, e in
                if index == 1 {
                    FlagCard(kicker: e.title, text: e.body)
                } else if index != last {
                    NoteCard(kicker: e.title, text: e.body)
                }
            }

            #if os(iOS)
            // The iPhone-only reality: this is a sideloaded build, so set the re-sign + unlock
            // expectation up front rather than letting it surprise people later (#222 / cert expiry).
            NoteCard(kicker: String(localized: "Installed outside the App Store"),
                     text: String(localized: "On iPhone this is a sideloaded build. Re-sign it about every 7 days on a free Apple ID (longer on a paid account). After your phone reboots, unlock it once so NOOP can read and sync its data."))
            #endif

            if last >= 0 {
                TakeawayCard(kicker: items[last].title, text: items[last].body)
            }
        }
    }
}

// MARK: - Step 4 · Bluetooth priming

private struct BluetoothStep: View {
    let cta: OnboardingCTA

    var body: some View {
        SheetPage(cta: cta) {
            SkyHeader(kicker: String(localized: "Bluetooth"),
                      statement: String(localized: "A quick word before we connect"),
                      bodyCopy: String(localized: "\(Platform.deviceNoun) will ask for Bluetooth in a moment."))
        } content: {
            NoteCard(kicker: String(localized: "Nothing leaves your \(Platform.deviceNoun)"),
                     text: String(localized: "NOOP talks to your strap directly over Bluetooth Low Energy. There's no server in the middle. The connection is local, and so is every reading it pulls in."))
            TakeawayCard(text: String(localized: "When the system prompt appears, choose Allow so NOOP can find your strap."))
        }
    }
}

// MARK: - Step 5 · Wear & wake

private struct WearStep: View {
    let cta: OnboardingCTA

    var body: some View {
        SheetPage(cta: cta) {
            SkyHeader(kicker: String(localized: "Your strap"),
                      statement: String(localized: "Put your strap on"),
                      bodyCopy: String(localized: "And make sure it's charged."))
        } content: {
            ChecklistCard(lines: [
                String(localized: "Wear it snug on your wrist or bicep, sensor against skin."),
                String(localized: "Give it a few minutes of charge if the battery is low."),
                String(localized: "Keep it within about a metre of \(Platform.deviceNounPhrase)."),
            ])
        }
    }
}

// MARK: - Step 6 · Scan (radar + strap picker)

private struct ScanStep: View {
    let cta: OnboardingCTA
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveState

    @State private var scanning = false
    @State private var showHelp = false

    /// Which strap to look for — shared with the Live screen via the same key.
    @AppStorage("selectedWhoopModel") private var selectedModelRaw = WhoopModel.whoop4.rawValue
    private var selectedModel: WhoopModel { WhoopModel(rawValue: selectedModelRaw) ?? .whoop4 }

    var body: some View {
        SheetPage(cta: cta) {
            VStack(spacing: 22) {
                RadarRings(active: scanning && !live.bonded, bonded: live.bonded)
                Text(statusText).skyStatement(size: 30)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
        } content: {
            GroupCard(LocalizedStringKey(String(localized: "Which strap are you pairing?"))) {
                ForEach(WhoopModel.allCases) { m in
                    Button { restartScan(for: m) } label: {
                        GroupRow(leading: .icon(m == selectedModel ? "checkmark.circle.fill" : "circle",
                                                m == selectedModel ? StrandPalette.accent : StrandPalette.textTertiary),
                                 title: LocalizedStringKey(m.displayName),
                                 value: m == .whoop4 ? String(localized: "Fully supported") : nil,
                                 valueColor: StrandPalette.textTertiary) {
                            if m == .whoop5mg { ExperimentalTag() }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // Proactive 5/MG guidance (#130): the strap bonds to one host at a time, so a scan here
            // finds nothing while it's still paired in the official WHOOP app.
            if selectedModel == .whoop5mg {
                FlagCard(text: String(localized: "WHOOP 5.0/MG pairs with one app at a time. If nothing's found, unpair it in the official WHOOP app and fully close that app, then Scan."))
            }

            if !live.bonded {
                Button(action: { startScan() }) {
                    Label(scanning ? "Scanning…" : "Scan", systemImage: "dot.radiowaves.left.and.right")
                }
                .buttonStyle(.noopSecondary)
                .disabled(scanning)

                GroupCard {
                    Button {
                        withAnimation(StrandMotion.gentle) { showHelp.toggle() }
                    } label: {
                        GroupRow(title: "Don't see it? That's normal.", showsChevron: !showHelp) {
                            if showHelp {
                                Image(systemName: "chevron.up")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(StrandPalette.textTertiary.opacity(0.7))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                if showHelp { reassurance }

                // WHOOP is NOOP's primary band, so onboarding leads with it — but it isn't required.
                // Make that obvious so a non-WHOOP user doesn't feel stuck here: they can continue now
                // and pair a heart-rate strap or import data afterwards (in Devices / Data Sources).
                SheetFootnote(text: String(localized: "No WHOOP? You can still continue. Pair a heart-rate strap (Polar, Wahoo, Coospo, Garmin HRM…) or a gym machine under Devices, or import from WHOOP, Apple Health, Oura, Fitbit, Garmin and more under Data Sources. You can do either any time."))
            }
        }
        // Auto-start: the prior Bluetooth step already told the user "so NOOP can find your strap",
        // so this step should already be searching when it appears rather than sitting on a dead,
        // unpulsing radar until they notice and tap Scan themselves.
        .onAppear { if !live.bonded { startScan() } }
        .onDisappear { scanning = false }
    }

    /// The header statement, driven entirely by real link state — never a canned "Searching…".
    private var statusText: String {
        if live.bonded { return String(localized: "Bonded. You're set.") }
        if live.connected { return String(localized: "Connecting…") }
        if scanning { return String(localized: "Searching…") }
        return String(localized: "Find your strap")
    }

    private func startScan(model scanModel: WhoopModel? = nil) {
        let modelToScan = scanModel ?? selectedModel
        scanning = true
        showHelp = false
        model.scan(model: modelToScan)
        // Surface the reassurance card if we haven't bonded after a calm beat.
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) {
            if !live.bonded {
                scanning = false
                withAnimation(StrandMotion.gentle) { showHelp = true }
            }
        }
    }

    private func restartScan(for newModel: WhoopModel) {
        selectedModelRaw = newModel.rawValue
        guard !live.bonded else { return }
        model.disconnect()
        startScan(model: newModel)
    }

    // The calm, never-alarmist "can't find it" card.
    private var reassurance: some View {
        StrandCard(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                Text("WHOOP straps don't appear in your \(Platform.deviceNoun)'s Bluetooth settings. They advertise on a custom profile that only apps like NOOP can find, so there's nothing to pair there, and you shouldn't try.")
                    .font(StrandFont.subhead)
                    .foregroundStyle(StrandPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Divider().overlay(StrandPalette.hairline)

                VStack(alignment: .leading, spacing: 10) {
                    Checkline(text: String(localized: "It's charged and worn. The sensor needs skin contact to wake."))
                    Checkline(text: String(localized: "It isn't held by the WHOOP phone app. Only one host at a time: close the app or turn off its Bluetooth."))
                    Checkline(text: String(localized: "It's within about a metre of \(Platform.deviceNounPhrase)."))
                }

                Button(action: retry) {
                    Label("Try again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.noopSecondary)
                .padding(.top, 2)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func retry() {
        withAnimation(StrandMotion.gentle) { showHelp = false }
        startScan()
    }
}

/// The clay "Experimental" pill on the 5.0/MG row.
private struct ExperimentalTag: View {
    var body: some View {
        Text("Experimental")
            .font(StrandFont.overlineScaled(10))
            .tracking(0.8)
            .foregroundStyle(StrandPalette.statusCritical)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(StrandPalette.criticalMuted))
    }
}

// MARK: - Step 7 · Bonding celebration

private struct BondedStep: View {
    let cta: OnboardingCTA
    @EnvironmentObject private var live: LiveState
    @State private var bloom = false

    /// The strap the user chose to pair — the only device identity this step actually has.
    @AppStorage("selectedWhoopModel") private var selectedModelRaw = WhoopModel.whoop4.rawValue

    var body: some View {
        VStack(spacing: 30) {
            Spacer(minLength: 0)

            Circle()
                .fill(.white.opacity(0.94))
                .frame(width: 92, height: 92)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 38, weight: .medium))
                        .foregroundStyle(HearthTheme.onboardingBondedSky.top)
                )
                .scaleEffect(bloom ? 1 : 0.7)
                .opacity(bloom ? 1 : 0)

            Text("You're connected.").skyStatement(size: 38)

            // Fact pills — only what's genuinely known here. The battery pill is omitted entirely
            // until the strap has actually reported a level (it often hasn't yet at bond time);
            // showing a placeholder percentage would be inventing a reading.
            HStack(spacing: 10) {
                if let name = WhoopModel(rawValue: selectedModelRaw)?.displayName {
                    SkyFactPill(text: name)
                }
                if let pct = live.batteryPct {
                    SkyFactPill(text: String(localized: "Battery \(Int(pct))%"))
                }
            }
            .opacity(bloom ? 1 : 0)

            Spacer(minLength: 0)

            OnboardingPillButton(cta: cta)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 30)
        .padding(.bottom, 40)
        .onAppear { withAnimation(StrandMotion.hero) { bloom = true } }
    }
}

/// An outlined pill stating one known fact, on the sky.
private struct SkyFactPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(StrandFont.caption)
            .foregroundStyle(.white.opacity(0.72))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .overlay(Capsule().strokeBorder(.white.opacity(0.24), lineWidth: 1))
    }
}

// MARK: - Step 8 · Profile

private struct ProfileStep: View {
    let cta: OnboardingCTA
    @EnvironmentObject private var profile: ProfileStore

    // Imperial/Metric display preference (D#103). The stored profile is always SI; the steppers keep
    // operating in SI (0.5 kg / 1 cm) and only the DISPLAYED value re-labels to lb / ft-in.
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue
    private var unitSystem: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    private let sexes: [(String, String)] = [
        ("male", String(localized: "Male")), ("female", String(localized: "Female")),
        ("nonbinary", String(localized: "Other"))
    ]

    var body: some View {
        SheetPage(cta: cta) {
            SkyHeader(kicker: String(localized: "About you"),
                      statement: String(localized: "So your zones, calories and baselines are accurate."))
        } content: {
            StrandCard(padding: 20) {
                VStack(spacing: 18) {
                    // #146: capture a date of birth so age advances on its own instead of going stale.
                    DatePicker(selection: $profile.dateOfBirth,
                               in: ProfileStore.dateOfBirthRange,
                               displayedComponents: .date) {
                        FieldRow(label: String(localized: "Date of birth"),
                                 value: String(localized: "\(profile.age) yrs"))
                    }
                    .tint(StrandPalette.accent)

                    Divider().overlay(StrandPalette.hairline)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sex").strandOverline()
                        Picker("Sex", selection: $profile.sex) {
                            ForEach(sexes, id: \.0) { key, label in
                                Text(label).tag(key)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    Divider().overlay(StrandPalette.hairline)

                    // Units control (#781). Without this, onboarding read `unitSystemRaw` for the
                    // Weight/Height display but had NO way to set it, so US users were locked to
                    // kg/cm until they later found Settings → Units. Mirror the Sex picker idiom; the
                    // stored profile stays SI either way, only the displayed labels re-format (lb / ft-in
                    // via UnitFormatter). Same key (`units.system`) the Settings → Units card writes.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Units").strandOverline()
                        Picker("Units", selection: $unitSystemRaw) {
                            Text("Metric").tag(UnitSystem.metric.rawValue)
                            Text("Imperial").tag(UnitSystem.imperial.rawValue)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    Divider().overlay(StrandPalette.hairline)

                    // Steppers, not sliders — matches the Age row above and the macOS Settings
                    // profile editor (same ranges/steps), so every numeric profile field is
                    // consistent across onboarding and Settings on both platforms.
                    Stepper(value: $profile.weightKg, in: 30...250, step: 0.5) {
                        FieldRow(label: String(localized: "Weight"),
                                 value: UnitFormatter.massFromKilograms(profile.weightKg, system: unitSystem))
                    }

                    Divider().overlay(StrandPalette.hairline)

                    Stepper(value: $profile.heightCm, in: 120...230, step: 1) {
                        FieldRow(label: String(localized: "Height"),
                                 value: UnitFormatter.heightFromCentimeters(profile.heightCm, system: unitSystem))
                    }
                }
            }

            SheetFootnote(text: String(localized: "Estimated max heart rate · \(profile.hrMax) bpm"))
        }
    }
}

// MARK: - Step 9 · Import (optional)

private struct ImportStep: View {
    let cta: OnboardingCTA
    @EnvironmentObject private var model: AppModel
    @State private var showingImporter = false
    @State private var importTarget: ImportTarget = .whoop

    var body: some View {
        SheetPage(cta: cta) {
            SkyHeader(kicker: String(localized: "Your history"),
                      statement: String(localized: "Bring your history"),
                      bodyCopy: String(localized: "Optional: import now, or continue and return to Data Sources later."))
        } content: {
            NoteCard(kicker: String(localized: "History fills the dashboard immediately"),
                     text: String(localized: "A WHOOP export backfills recovery, strain, sleep and workouts. Apple Health can add HR, HRV, sleep, SpO₂, steps, workouts and weight."))

            StrandCard(padding: 20) {
                VStack(spacing: 10) {
                    ImportActionButton(
                        title: model.isImporting(.whoop) ? String(localized: "Importing…") : String(localized: "Import WHOOP export"),
                        systemImage: "tray.and.arrow.down",
                        disabled: model.hasActiveImport
                    ) {
                        presentImporter(.whoop)
                    }
                    ImportActionButton(
                        title: model.isImporting(.appleHealth) ? String(localized: "Working…") : String(localized: "Import Apple Health export"),
                        systemImage: "heart.fill",
                        disabled: model.hasActiveImport
                    ) {
                        presentImporter(.appleHealth)
                    }
                }
            }

            if model.hasActiveImport {
                ProgressView()
                    .controlSize(.small)
                    .tint(StrandPalette.accent)
                    .frame(maxWidth: .infinity)
            }

            // Show the summary for the source the user last imported, styled off the typed
            // failure flag (not a substring match) so real errors read as warnings.
            if let summary = lastSummary {
                Text(summary)
                    .font(StrandFont.subhead)
                    .foregroundStyle(model.importFailed(importKind) ? StrandPalette.statusWarning : StrandPalette.statusPositive)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: importTarget.allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleImportResult(result, for: importTarget)
        }
    }

    /// The AppModel source kind matching the last-chosen import target.
    private var importKind: DataSourceImportKind {
        switch importTarget {
        case .whoop: return .whoop
        case .appleHealth: return .appleHealth
        }
    }

    /// The summary for the source the user last imported in this step.
    private var lastSummary: String? {
        switch importTarget {
        case .whoop: return model.whoopImportSummary
        case .appleHealth: return model.appleHealthImportSummary
        }
    }

    private func presentImporter(_ target: ImportTarget) {
        importTarget = target
        showingImporter = true
    }

    private func handleImportResult(_ result: Result<[URL], Error>, for target: ImportTarget) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        switch target {
        case .whoop:
            model.importWhoop(url: url)
        case .appleHealth:
            model.importAppleHealth(url: url)
        }
    }

    private enum ImportTarget {
        case whoop
        case appleHealth

        var allowedContentTypes: [UTType] {
            // See DataSourcesView: `.folder` is a macOS-only affordance (pick an unzipped export
            // directory). On iOS it greys out the .zip in the Files picker (issue #179), so iOS
            // offers only the concrete file types.
            switch self {
            case .whoop:
                #if os(macOS)
                return [.zip, .folder]
                #else
                return [.zip]
                #endif
            case .appleHealth:
                #if os(macOS)
                return [.zip, .xml, .folder]
                #else
                return [.zip, .xml]
                #endif
            }
        }
    }
}

// MARK: - Step 10 · Notifications (wrist alerts priming)

private struct NotificationsStep: View {
    let cta: OnboardingCTA

    var body: some View {
        SheetPage(cta: cta) {
            SkyHeader(kicker: String(localized: "Notifications"),
                      statement: String(localized: "Stay in the loop"),
                      bodyCopy: String(localized: "NOOP can tap your wrist when your \(Platform.deviceNoun) needs you. No glance at the screen required."))
        } content: {
            #if os(iOS)
            // iOS gives an app no way to observe *other* apps' notifications, and the per-app picker
            // behind it is NSWorkspace-based (macOS-only). So drop the cross-app relay claim here and
            // keep only what iOS genuinely does: NOOP's own strain nudges + smart alarm buzz the strap
            // directly over BLE.
            NoteCard(kicker: String(localized: "A buzz, not a banner"),
                     text: String(localized: "NOOP taps your strap so an alert lands on your wrist instead of your screen. No need to reach for it. Everything stays on \(Platform.deviceNounPhrase)."))

            ChecklistCard(lines: [
                String(localized: "Strain nudges and your smart alarm tap your wrist the moment they fire."),
                String(localized: "It all stays on your strap and \(Platform.deviceNounPhrase): no account, no cloud."),
            ])
            #else
            NoteCard(kicker: String(localized: "A buzz, not a banner"),
                     text: String(localized: "When the \(Platform.deviceNoun) apps you choose send a notification, NOOP taps your strap: Slack, Calendar, Messages, whatever matters. Everything stays on \(Platform.deviceNounPhrase)."))

            ChecklistCard(lines: [
                String(localized: "Pick which apps reach your wrist in Settings → Notifications."),
                String(localized: "Strain nudges and your smart alarm tap your wrist the same way."),
            ])
            #endif

            // The OS prompt fires on LEAVING this step (see OnboardingWizard.advance), so say so here.
            TakeawayCard(text: String(localized: "The system prompt comes next. Whichever you choose, nothing leaves \(Platform.deviceNounPhrase)."))
        }
    }
}

// MARK: - Step 11 · Appearance

/// Lets a brand-new user pick the app's look up front (and learn it's changeable) — the same
/// System / Light / Dark setting that lives in Settings → Appearance. Selecting re-themes the whole
/// app live (the shared `@AppStorage(AppearanceMode.storageKey)` drives `preferredColorScheme`), so
/// the wizard itself IS the preview.
private struct AppearanceStep: View {
    let cta: OnboardingCTA
    @AppStorage(AppearanceMode.storageKey) private var appearanceRaw = AppearanceMode.system.rawValue
    private var binding: Binding<AppearanceMode> {
        Binding(get: { AppearanceMode(rawValue: appearanceRaw) ?? .system },
                set: { appearanceRaw = $0.rawValue })
    }

    var body: some View {
        SheetPage(cta: cta) {
            SkyHeader(kicker: String(localized: "Appearance"),
                      statement: String(localized: "Make it yours"),
                      bodyCopy: String(localized: "Choose how NOOP looks. The whole app updates as you tap."))
        } content: {
            StrandCard(padding: 20) {
                SegmentedPillControl(AppearanceMode.allCases, selection: binding) { $0.label }
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            SheetFootnote(text: String(localized: "System follows your \(Platform.deviceNoun)'s light or dark setting. You can change this any time in Settings → Appearance."))
        }
    }
}

// MARK: - The thread (progress)

/// The mockup's hairline thread: a 2pt track that fills left-to-right as the flow advances, and goes
/// SOLID (no track/fill split) on the final frame — "thread complete".
private struct ThreadProgress: View {
    var progress: Double           // 0...1
    var complete: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                if !complete {
                    Capsule().fill(.white.opacity(0.18))
                }
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: complete ? geo.size.width : max(4, geo.size.width * progress))
                    .animation(StrandMotion.gentle, value: progress)
            }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }
}

// MARK: - Radar rings

/// The mockup's searching indicator: three FLAT concentric rings, no sweep wedge, no gradient. While
/// scanning the outer rings breathe outward; bonded turns the core sage. Reduce Motion / Low Power
/// leave it at its resting frame.
private struct RadarRings: View {
    var active: Bool
    var bonded: Bool
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Low Power Mode / "Reduce motion in NOOP" pose these looping animations still too. Onboarding is
    /// first-run only, but a `repeatForever` is a `repeatForever` wherever it lives.
    @ObservedObject private var motion = NoopMotionState.shared
    private var poseStill: Bool { motion.poseStill(reduceMotion) }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                .frame(width: 150, height: 150)
                .scaleEffect(pulse ? 1.06 : 1)
            Circle()
                .strokeBorder(.white.opacity(0.30), lineWidth: 1)
                .frame(width: 100, height: 100)
                .scaleEffect(pulse ? 1.04 : 1)
            Circle()
                .fill(bonded ? StrandPalette.accent : .white.opacity(0.9))
                .frame(width: 58, height: 58)
        }
        .frame(width: 150, height: 150)
        .onAppear { if active && !poseStill { pulse = true } }
        .onChangeCompat(of: active) { isActive in
            pulse = isActive && !poseStill
        }
        .animation(active && !poseStill ? StrandMotion.breathe : StrandMotion.gentle, value: pulse)
        .accessibilityHidden(true)
    }
}

// MARK: - Reusable pieces

private struct Checkline: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(StrandPalette.statusPositive)
                .padding(.top, 2)
            Text(text)
                .font(StrandFont.subhead)
                .foregroundStyle(StrandPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

private struct FieldRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).strandOverline()
            Spacer()
            Text(value)
                .font(StrandFont.bodyNumber)
                .foregroundStyle(StrandPalette.textPrimary)
        }
    }
}

private struct ImportActionButton: View {
    let title: String
    let systemImage: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18)
                Text(title)
                    .font(StrandFont.subhead.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(StrandPalette.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.noopSecondary)
        .disabled(disabled)
        .opacity(disabled ? 0.55 : 1)
    }
}

// MARK: - Preview

#if DEBUG
private struct OnboardingPreview: View {
    @StateObject private var model = AppModel()
    var body: some View {
        OnboardingWizard(onFinished: {})
            .environmentObject(model)
            .environmentObject(model.live)
            .environmentObject(model.profile)
            .frame(width: 393, height: 852)
    }
}

#Preview("Onboarding") { OnboardingPreview() }
#endif

/// A one-off static sky layer for the wizard. `LiquidSkyStatic` renders a Canvas once (no
/// TimelineView), so three of these stacked cost three cached layers, not three animation loops.
private struct OnboardingSkyLayer: View {
    let stop: LiquidSkyStop
    var body: some View {
        LiquidSkyStatic(settleStrength: 0, stop: stop)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
