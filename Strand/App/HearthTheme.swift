import CoreText
import SwiftUI
import StrandDesign

// MARK: - Hearth theme (bknoop fork override layer)
//
// Everything in `Packages/StrandDesign` stays byte-identical to upstream — its tokens are `var`s
// (chrome) or `*Titanium`-suffixed `var`s (data ramps/domain worlds) specifically so a fork can
// override VALUES without touching the shared package's SOURCE, keeping merges from upstream clean.
// This file is the entire override: it runs once, at launch, before any SwiftUI view is constructed.
//
// Call `HearthTheme.apply()` as the FIRST line of both `StrandApp.init()` (macOS) and
// `StrandiOSApp.init()` (iOS) — before anything reads a `StrandPalette`/`StrandFont` token, since a
// handful of roles are read-through-computed but a few upstream call sites may cache a resolved
// SwiftUI `Font`/`Color` value in their own `@State`, which only reflects whatever was current at
// that call's construction.
enum HearthTheme {
    private static var applied = false

    static func apply() {
        guard !applied else { return }
        applied = true
        registerBundledFonts()
        applyTypography()
        applyPalette()
        applySky()
    }

    // MARK: - Fonts

    /// Bundled font files under `Strand/Resources/Fonts/` — (file name, PostScript name). The
    /// PostScript name is what `Font.custom(_:)` actually looks up; it's NOT always the same as the
    /// filename or a "family + weight" composition (Work Sans' Medium/SemiBold statics register
    /// under their OWN family, not sharing "Work Sans" — confirmed via fontTools — so `.weight()`
    /// cannot find them; every weight is addressed by its exact PostScript name instead).
    private static let bundledFonts: [(file: String, postScriptName: String)] = [
        ("WorkSans-Regular", "WorkSans-Regular"),
        ("WorkSans-Medium", "WorkSans-Medium"),
        ("WorkSans-SemiBold", "WorkSans-SemiBold"),
        ("WorkSans-Bold", "WorkSans-Bold"),
        ("SourceSerif4-Light", "SourceSerif4-Light"),
    ]

    private static func registerBundledFonts() {
        for entry in bundledFonts {
            guard let url = Bundle.main.url(forResource: entry.file, withExtension: "ttf") else {
                assertionFailure("HearthTheme: missing bundled font \(entry.file).ttf")
                continue
            }
            var error: Unmanaged<CFError>?
            // .process scope: visible to this process only, no persistent system-wide install —
            // matches "nothing this app does touches state outside itself" for a font, not just data.
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error), let error {
                assertionFailure("HearthTheme: failed to register \(entry.file): \(error.takeUnretainedValue())")
            }
        }
    }

    private static func postScriptName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black: return "WorkSans-Bold"
        case .semibold: return "WorkSans-SemiBold"
        case .medium: return "WorkSans-Medium"
        default: return "WorkSans-Regular" // regular, light, ultraLight, thin — Work Sans Light isn't bundled; Regular is the honest floor
        }
    }

    private static func applyTypography() {
        StrandFont.family = "WorkSans-Regular"
        StrandFont.voiceFamily = "SourceSerif4-Light"
        // Mockup's "Big number" role is Sans 200 (thin), not upstream's bold gauge numeral.
        StrandFont.displayWeight = .thin
        StrandFont.resolveFamily = { size, weight, style in
            let name = postScriptName(for: weight)
            if let style {
                return .custom(name, size: size, relativeTo: style)
            }
            return .custom(name, size: size)
        }
        StrandFont.resolveVoiceFamily = { size, style in
            if let style {
                return .custom("SourceSerif4-Light", size: size, relativeTo: style)
            }
            return .custom("SourceSerif4-Light", size: size)
        }
    }

    // MARK: - Palette
    //
    // Hearth: a single warm-paper look (same values in light and dark — see Palette.swift's own
    // OVERRIDE POINT note). Sage is the one accent hue; amber covers Effort/warning-adjacent tones;
    // terracotta covers critical. Values are sourced from the "bknoop Build" Claude Design mockup.

    private static func applyPalette() {
        // Surfaces
        StrandPalette.surfaceBase    = Color(light: "#E9E5DB", dark: "#E9E5DB")
        StrandPalette.surfaceRaised  = Color(light: "#F6F3EC", dark: "#F6F3EC")
        StrandPalette.surfaceOverlay = Color(light: "#F6F3EC", dark: "#F6F3EC")
        StrandPalette.surfaceInset   = Color(light: "#DED9CC", dark: "#DED9CC")
        StrandPalette.hairline       = Color(light: "#E7E2D4", dark: "#E7E2D4")
        StrandPalette.hairlineStrong = Color(light: "#D5CFC0", dark: "#D5CFC0")

        // Text
        StrandPalette.textPrimary   = Color(light: "#16150F", dark: "#16150F")
        StrandPalette.textSecondary = Color(light: "#56534A", dark: "#56534A")
        // Darker than the mockup's own #938E7D meta tone (~3:1 against surfaceRaised, below AA for
        // small text like captions/footnotes/rung sub-labels) — same warm-grey family, better floor.
        StrandPalette.textTertiary  = Color(light: "#6B6759", dark: "#6B6759")
        StrandPalette.onDarkPrimary   = Color(hex: "#F6F3EC")
        StrandPalette.onDarkSecondary = Color(hex: "#C9C3B1")
        StrandPalette.onDarkTertiary  = Color(hex: "#9C9789")
        StrandPalette.glowAmbient = Color(light: "#EFE3C9", dark: "#EFE3C9")

        // Accent — sage, one hue in both schemes
        StrandPalette.accent      = Color(light: "#5F7D6A", dark: "#5F7D6A")
        StrandPalette.accentHover = Color(light: "#4A6656", dark: "#4A6656")
        StrandPalette.accentMuted = Color(light: "#E1E9E2", dark: "#E1E9E2")
        StrandPalette.focusRing   = Color(light: "#5F7D6A", dark: "#5F7D6A")
        // Clay — the Alert card's flagged wash, distinct from sage's "conclusion" wash above.
        StrandPalette.criticalMuted = Color(light: "#F3E2DE", dark: "#F3E2DE")

        // Recovery / Charge ramp — terracotta (depleted) → amber → sage (peak)
        StrandPalette.recovery000 = Color(light: "#B4543F", dark: "#B4543F")
        StrandPalette.recovery030 = Color(light: "#C17652", dark: "#C17652")
        StrandPalette.recovery055 = Color(light: "#C09A5E", dark: "#C09A5E")
        StrandPalette.recovery078 = Color(light: "#8FA383", dark: "#8FA383")
        StrandPalette.recovery100 = Color(light: "#5F7D6A", dark: "#5F7D6A")

        // Strain / Effort ramp — ember → amber
        StrandPalette.strain000 = Color(light: "#8D6A54", dark: "#8D6A54")
        StrandPalette.strain033 = Color(light: "#A96A57", dark: "#A96A57")
        StrandPalette.strain066 = Color(light: "#C09A5E", dark: "#C09A5E")
        StrandPalette.strain100 = Color(light: "#D4B37A", dark: "#D4B37A")

        // Sleep stages — exact mockup ramp
        StrandPalette.sleepAwakeTitanium = Color(light: "#C6A392", dark: "#C6A392")
        StrandPalette.sleepLightTitanium = Color(light: "#AFC0B0", dark: "#AFC0B0")
        StrandPalette.sleepDeepTitanium  = Color(light: "#3E5648", dark: "#3E5648")
        StrandPalette.sleepREMTitanium   = Color(light: "#6F8F79", dark: "#6F8F79")

        // HR zones — sage → amber → terracotta
        StrandPalette.zone1Titanium = Color(light: "#8FA383", dark: "#8FA383")
        StrandPalette.zone2Titanium = Color(light: "#C09A5E", dark: "#C09A5E")
        StrandPalette.zone3Titanium = Color(light: "#C17652", dark: "#C17652")
        StrandPalette.zone4Titanium = Color(light: "#B4543F", dark: "#B4543F")
        StrandPalette.zone5Titanium = Color(light: "#8C3A31", dark: "#8C3A31")

        // Status
        StrandPalette.statusPositiveTitanium = Color(light: "#5F7D6A", dark: "#5F7D6A")
        StrandPalette.statusWarningTitanium  = Color(light: "#C09A5E", dark: "#C09A5E")
        StrandPalette.statusCriticalTitanium = Color(light: "#B4543F", dark: "#B4543F")

        // Per-metric accents
        StrandPalette.metricCyanTitanium   = Color(light: "#7B9070", dark: "#7B9070")
        StrandPalette.metricPurpleTitanium = Color(light: "#8B6F7D", dark: "#8B6F7D")
        StrandPalette.metricAmberTitanium  = Color(light: "#C09A5E", dark: "#C09A5E")
        StrandPalette.metricRoseTitanium   = Color(light: "#B4543F", dark: "#B4543F")

        // Domain colour worlds — Charge sage, Effort amber, Rest teal-slate, Stress sage→amber→terracotta
        StrandPalette.chargeColorTitanium  = Color(light: "#5F7D6A", dark: "#5F7D6A")
        StrandPalette.chargeDeepTitanium   = Color(light: "#3E5648", dark: "#3E5648")
        StrandPalette.chargeBrightTitanium = Color(light: "#8FA383", dark: "#8FA383")
        StrandPalette.chargeGlowTitanium   = Color(light: "#5F7D6A", dark: "#5F7D6A")

        StrandPalette.effortColorTitanium  = Color(light: "#C09A5E", dark: "#C09A5E")
        StrandPalette.effortDeepTitanium   = Color(light: "#8D6A54", dark: "#8D6A54")
        StrandPalette.effortBrightTitanium = Color(light: "#D4B37A", dark: "#D4B37A")
        StrandPalette.effortGlowTitanium   = Color(light: "#C09A5E", dark: "#C09A5E")

        StrandPalette.restColorTitanium  = Color(light: "#5B7A80", dark: "#5B7A80")
        StrandPalette.restDeepTitanium   = Color(light: "#3D5459", dark: "#3D5459")
        StrandPalette.restBrightTitanium = Color(light: "#8FA9AC", dark: "#8FA9AC")
        StrandPalette.restGlowTitanium   = Color(light: "#5B7A80", dark: "#5B7A80")

        StrandPalette.stressColorTitanium  = Color(light: "#C09A5E", dark: "#C09A5E")
        StrandPalette.stressDeepTitanium   = Color(light: "#5F7D6A", dark: "#5F7D6A")
        StrandPalette.stressBrightTitanium = Color(light: "#B4543F", dark: "#B4543F")
        StrandPalette.stressGlowTitanium   = Color(light: "#C09A5E", dark: "#C09A5E")

        // Scenic background + frosted-card endpoints
        StrandPalette.scenicCenter   = Color(light: "#F6F3EC", dark: "#F6F3EC")
        StrandPalette.scenicEdge     = Color(light: "#E9E5DB", dark: "#E9E5DB")
        StrandPalette.scenicStar     = Color(light: "#D5CFC0", dark: "#D5CFC0")
        StrandPalette.cardFillTop    = Color(light: "#F6F3EC", dark: "#F6F3EC")
        StrandPalette.cardFillBottom = Color(light: "#EFEAD9", dark: "#EFEAD9")

        // Gold/titanium core (repointed to sage + warm-neutral, matching the accent repointing history)
        StrandPalette.gold         = Color(light: "#5F7D6A", dark: "#5F7D6A")
        StrandPalette.goldLight    = Color(light: "#8FA383", dark: "#8FA383")
        StrandPalette.goldDeep     = Color(light: "#3E5648", dark: "#3E5648")
        StrandPalette.goldDeepText = Color(hex: "#F6F3EC")
        StrandPalette.tipCore      = Color(light: "#F6F3EC", dark: "#F6F3EC")
        StrandPalette.signalYellow = Color(light: "#D4A24A", dark: "#D4A24A")
        StrandPalette.titaniumTop  = Color(light: "#F6F3EC", dark: "#F6F3EC")
        StrandPalette.titaniumMid  = Color(light: "#EAE5D7", dark: "#EAE5D7")
        StrandPalette.titaniumLow  = Color(light: "#DED9CC", dark: "#DED9CC")
        StrandPalette.titaniumDeep = Color(hex: "#C9C3B1")

        // Card shadow + radius — the mockup's "Handoff" reference sheet states these as exact canon:
        // radius 26 (not upstream's 22), shadow rgba(40,36,25,·) in two layers (wired in
        // StrandCard.swift), always on (the Hearth chrome no longer varies by system light/dark, so
        // gating the shadow on `scheme == .light` would make every card go flat under system Dark Mode
        // even though it still looks like a light warm-paper card).
        StrandPalette.cardShadowColor = Color(hex: "#282419")
        StrandPalette.cardShadowAlwaysOn = true
        NoopMetrics.cardRadius = 26
        // The mockup's radius scale distinguishes a card (26, above) from a divided list-row card
        // (24 — the "Group" card, the workhorse), a chip (20) and a widget/glance tile (34).
        NoopMetrics.rowCardRadius = 24
        NoopMetrics.chipRadius = 20
        NoopMetrics.widgetRadius = 34
    }

    // MARK: - Sky
    //
    // `LiquidSky`'s hero background is a continuous top→mid→horizon vertical gradient interpolated
    // across 10 hour-keyed stops (`liquidSkyKeys`) — a different rendering technique from the
    // mockup's 4 discrete off-center radial gradients, so these keyframes are an adaptation in the
    // same warm-paper family (dawn amber, midday sage-cream, dusk terracotta-rose, deep warm night)
    // rather than a literal port. `top` is the deepest tone, `horizon` the brightest/warmest — the
    // same convention upstream's cool-blue keyframes already use.

    private static func hx(_ hex: UInt32) -> Color {
        Color(.sRGB,
              red: Double((hex >> 16) & 0xff) / 255,
              green: Double((hex >> 8) & 0xff) / 255,
              blue: Double(hex & 0xff) / 255, opacity: 1)
    }

    private static func applySky() {
        // Sun position sweeps monotonically right-to-left across the day (0.78 at dawn -> 0.50 at
        // midday -> 0.18 at dusk), matching the mockup's own three named radial centers (morning
        // "76% 2%", midday "50% -4%", evening "18% 4%") with the hours between interpolated so the
        // glow slides continuously rather than jumping keyframe to keyframe — same `liquidSkyAt` lerp
        // every other field already gets.
        liquidSkyKeys = [
            .init(h: 0,    top: hx(0x12100B), mid: hx(0x1C1712), hor: hx(0x281F1C), stars: 1,    warm: 0,
                  sunX: 0.5,  sunY: 0.10, sunIntensity: 0),
            .init(h: 5,    top: hx(0x1A150F), mid: hx(0x3A2E22), hor: hx(0x6B4A38), stars: 0.5,  warm: 0.1,
                  sunX: 0.72, sunY: 0.14, sunIntensity: 0),
            .init(h: 6.5,  top: hx(0x26332C), mid: hx(0x4B5A48), hor: hx(0x9C8F5E), stars: 0.2,  warm: 0.3,
                  sunX: 0.78, sunY: 0.08, sunIntensity: 0.35),
            .init(h: 8.5,  top: hx(0x3E4B3D), mid: hx(0x6E7A5A), hor: hx(0xC7B183), stars: 0,    warm: 0.6,
                  sunX: 0.76, sunY: 0.02, sunIntensity: 0.7),
            .init(h: 11,   top: hx(0x33453A), mid: hx(0x6E8064), hor: hx(0xC7D0A8), stars: 0,    warm: 0.85,
                  sunX: 0.62, sunY: -0.02, sunIntensity: 0.85),
            // Midday's top/mid are deliberately deeper than the mockup's own 32%/14% stops (which read
            // as a medium-light sage, #7B9070/#B4C596): ScreenScaffold's header title/subtitle sit in
            // exactly this band, and #7B9070 under warm-white text measures ~3:1 contrast — below the
            // 4.5:1 AA floor for normal text. Horizon stays the mockup's pale cream; only the
            // text-adjacent stops moved.
            .init(h: 14,   top: hx(0x33453A), mid: hx(0x4E6653), hor: hx(0xEDF1DC), stars: 0,    warm: 1,
                  sunX: 0.50, sunY: -0.04, sunIntensity: 1.0),
            .init(h: 17.5, top: hx(0x45303E), mid: hx(0x74404A), hor: hx(0xC77A5E), stars: 0,    warm: 0.5,
                  sunX: 0.32, sunY: 0.0, sunIntensity: 0.6),
            .init(h: 19.5, top: hx(0x281F2C), mid: hx(0x45303E), hor: hx(0x9C5850), stars: 0.4,  warm: 0.15,
                  sunX: 0.18, sunY: 0.04, sunIntensity: 0.3),
            .init(h: 22,   top: hx(0x171320), mid: hx(0x221A22), hor: hx(0x3A2824), stars: 0.9,  warm: 0,
                  sunX: 0.5,  sunY: 0.10, sunIntensity: 0),
            .init(h: 24,   top: hx(0x12100B), mid: hx(0x1C1712), hor: hx(0x281F1C), stars: 1,    warm: 0,
                  sunX: 0.5,  sunY: 0.10, sunIntensity: 0),
        ]
    }

    /// The mockup's "alarm" sky — replaces the normal time-of-day gradient at the illness ladder's
    /// Major rung (see the call site in `LiquidTodayView`), via `liquidSkyOverride`. Orange-to-rust-to-
    /// near-black, a deliberate departure from the calm palette so a real multi-signal anomaly reads
    /// as visually different, not just another card.
    static let alarmSkyStop = LiquidSkyStop(
        h: 0, top: hx(0x1C1216), mid: hx(0x5E2422), hor: hx(0xC25C38),
        stars: 0, warm: 0.4, sunX: 0.74, sunY: -0.08, sunIntensity: 0.5
    )
}
