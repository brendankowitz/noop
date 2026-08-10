import SwiftUI
import StrandDesign

// MARK: - Apple Watch setup
//
// The honest onboarding flow for using NOOP with only an Apple Watch (M2 of the Watch-as-a-
// device project): what the watch is great at and where it's lighter than a chest strap, set
// BEFORE asking for anything, so the permission ask is informed and the tone stays honest. The
// Health permission itself triggers the existing HealthKitBridge.requestAuthorization — we never
// reimplement the request: the bridge owns the type list, the entitlement checks, and arming live
// ingestion once granted.
//
// Hearth layout (mockup 1c, left frame): this is a WIZARD, so unlike the reference pages it keeps a
// sky and modal chrome — the sky/kicker/serif header band from `ScreenScaffold`'s sheet layout, a ✕
// in the band's trailing slot (a modal closes, it does not pop), and the cream sheet below carrying
// three cards: the plain "your watch, NOOP's brain" card, a Group card of expectations, and the sage
// Conclusion card that ends in the ink "Allow Apple Health access" pill — the button lives INSIDE
// that card, since the conclusion and its one action are a single thought.
//
// The former two-step (intro → permission) wizard with a Continue/Back footer is now ONE scroll, per
// the mockup: the expectations and the ask are short enough to read in a single pass, and the ✕
// carries the dismiss that "Not now"/"Done" used to. Nothing about the request itself changed.
// macOS has no HealthKit, so the permission card there reads as "this needs an iPhone" rather than
// offering a button that can't work, the same honest reroute AppleHealthView already uses.
//
// Plain voice, no fabricated numbers, upfront about the limitations. Every expectation row's pill
// restates a claim this page (and the About page) already made in prose — none of them is a new
// tier the app can't stand behind.

struct AppleWatchSetupView: View {
    let onClose: () -> Void

    /// iOS-only: the live HealthKit bridge that owns the real permission request. macOS has no
    /// HealthKit, so this and every `health.*` use stays `#if os(iOS)`-gated.
    #if os(iOS)
    @EnvironmentObject private var health: HealthKitBridge
    #endif

    /// The "Every metric, and how sure NOOP is" row opens the reference page. This screen is
    /// presented as a SHEET and has no NavigationStack of its own, so the About page comes up as a
    /// second sheet rather than a push — and WITHOUT `onStartSetup`, so it can't loop back here.
    @State private var showAbout = false

    var body: some View {
        ScreenScaffold(title: "Apple Watch",
                       subtitle: "Use NOOP with your watch",
                       // A wizard, not reference material: it keeps the sky (mockup 1c, left frame).
                       topBackground: liquidScaffoldSky(),
                       trailing: { closeButton }) {
            brainCard
            expectationsCard
            calibrationNote
            permissionCard
        }
        #if os(macOS)
        .frame(width: 560, height: 640)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .noopSheetPresentation(largeFirst: true)
        #endif
        .sheet(isPresented: $showAbout) {
            NavigationStack {
                AppleWatchAboutView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showAbout = false }
                        }
                    }
                    #if os(iOS)
                    // The About page draws its own full-bleed ink band; an opaque bar would clip it.
                    .toolbarBackground(.hidden, for: .navigationBar)
                    #endif
            }
            #if os(macOS)
            .frame(width: 560, height: 640)
            #endif
        }
    }

    // MARK: - Modal chrome

    /// The mockup's ✕ disc in the sky band. On-dark tokens, not the text tokens: the band is dark in
    /// both schemes, so a `textTertiary` glyph would be ink-on-ink.
    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(StrandPalette.onDarkPrimary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.white.opacity(0.16)))
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel("Close")
    }

    // MARK: - What the watch is, in one card

    private var brainCard: some View {
        NoopCard(padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("YOUR WATCH, NOOP'S BRAIN").strandOverline()
                Text("No chest strap? No problem. NOOP can run off only your Apple Watch. It reads your watch's data through Apple Health and works out your Charge, Rest, Effort and Fitness Age right here on your phone. Everything stays on the device.")
                    .font(StrandFont.body)
                    .foregroundStyle(StrandPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - What to expect
    //
    // Each pill restates something this flow already said in prose: "Great" is the page's own
    // "what it's great at" list, "Sparser" is the About page's word for how a watch samples HRV
    // rather than streaming it, and "Model" is the wrist-temperature / blood-oxygen caveat. The last
    // row is the mockup's chevron into the full per-metric table.

    private var expectationsCard: some View {
        GroupCard("WHAT TO EXPECT") {
            GroupRow(title: "Sleep, workouts and steps") {
                StatePill("Great", tone: .positive, showsDot: false)
            }
            .accessibilityElement(children: .combine)

            GroupRow(title: "Fitness Age") {
                StatePill("Great", tone: .positive, showsDot: false)
            }
            .accessibilityElement(children: .combine)

            GroupRow(title: "Overnight HRV density") {
                StatePill("Sparser", tone: .warning, showsDot: false)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Overnight heart-rate variability density. Sparser than a chest strap.")

            GroupRow(title: "Wrist temp, blood oxygen") {
                StatePill("Model", tone: .neutral, showsDot: false)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Wrist temperature and blood oxygen. Depends on your watch model.")

            Button {
                showAbout = true
            } label: {
                GroupRow(title: "Every metric, and how sure NOOP is", showsChevron: true)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel("Every metric, and how sure NOOP is")
            .accessibilityHint("Opens the About Apple Watch data page")
        }
    }

    private var calibrationNote: some View {
        Text("Charge needs about seven nights of your heart-rate variability before it appears. Until then NOOP says it needs more data, never a guessed number.")
            .font(StrandFont.footnote)
            .foregroundStyle(StrandPalette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }

    // MARK: - Connect Apple Health (the one conclusion, and its one action)

    @ViewBuilder private var permissionCard: some View {
        #if os(iOS)
        ConclusionCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text("CONNECT APPLE HEALTH")
                        .font(StrandFont.overline)
                        .tracking(StrandFont.overlineTracking)
                        .foregroundStyle(StrandPalette.accentHover)
                    Spacer(minLength: 8)
                    if health.auth == .authorized {
                        StatePill(health.syncing ? "Syncing" : "Connected",
                                  tone: .positive, pulsing: health.syncing)
                    }
                }

                switch health.auth {
                case .unavailable:
                    Text("Apple Health isn't available on this device, so there's nothing to connect here.")
                        .font(StrandFont.body)
                        .foregroundStyle(StrandPalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                case .entitlementMissing:
                    // The sideload was re-signed without the HealthKit entitlement (free Apple IDs always
                    // lack it, and some paid reseller certs do too, #930), so the request can never present
                    // and the app can never appear under Settings › Health. Give the honest path instead
                    // of an impossible Settings instruction (mirrors #348).
                    Text("This install can't connect to Apple Health directly. It was signed with a profile that doesn't include Apple's Health permission, so there's nothing to grant here.")
                        .font(StrandFont.body)
                        .foregroundStyle(StrandPalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("You can still bring your data in by importing a Health export from Data Sources. A build from the App Store, or one signed with a paid Apple Developer account, connects directly.")
                        .font(StrandFont.footnote)
                        .foregroundStyle(StrandPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                case .unknown, .denied:
                    Text("NOOP reads your heart rate, HRV, resting heart rate, sleep, steps, energy and VO₂ max from Apple Health to compute your scores. It all stays on this iPhone, and you pick exactly what to share on the next screen.")
                        .font(StrandFont.body)
                        .foregroundStyle(StrandPalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        // The bridge owns the real request: the type list, the entitlement checks, and
                        // arming continuous live ingestion once granted. We just trigger it.
                        Task { await health.requestAuthorization() }
                    } label: {
                        Text("Allow Apple Health access")
                    }
                    .buttonStyle(NoopButtonStyle(.primary, fullWidth: true))
                    .accessibilityHint("Shows the Apple Health permission sheet")
                    if health.auth == .denied {
                        Text("If you don't see the prompt, turn NOOP on under Settings › Health › Data Access & Devices.")
                            .font(StrandFont.footnote)
                            .foregroundStyle(StrandPalette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                case .authorized:
                    Text("You're connected. NOOP is reading your Apple Watch data now. Your Charge score will spend its first week or so calibrating, then settle in.")
                        .font(StrandFont.body)
                        .foregroundStyle(StrandPalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button {
                        onClose()
                    } label: {
                        Text("Done")
                    }
                    .buttonStyle(NoopButtonStyle(.primary, fullWidth: true))
                    .keyboardShortcut(.defaultAction)
                    Text("You can change what you share any time in Settings › Health › Data Access & Devices.")
                        .font(StrandFont.footnote)
                        .foregroundStyle(StrandPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let err = health.lastError {
                    Text(err)
                        .font(StrandFont.footnote)
                        .foregroundStyle(StrandPalette.statusCritical)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        #else
        // macOS has no HealthKit at all. Be honest: the watch path is an iPhone feature.
        ConclusionCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("SET THIS UP ON YOUR IPHONE")
                    .font(StrandFont.overline)
                    .tracking(StrandFont.overlineTracking)
                    .foregroundStyle(StrandPalette.accentHover)
                Text("Apple Health lives on the iPhone, not the Mac, so connecting your Apple Watch happens there. Open NOOP on your iPhone, head to Settings, and run this same Apple Watch setup. Your scores then show up across your devices.")
                    .font(StrandFont.body)
                    .foregroundStyle(StrandPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        #endif
    }
}

#if DEBUG
#Preview("Apple Watch setup") {
    AppleWatchSetupView(onClose: {})
}
#endif
