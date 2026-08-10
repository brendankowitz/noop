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
        ("WorkSans-ExtraLight", "WorkSans-ExtraLight"),
        ("WorkSans-Light", "WorkSans-Light"),
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
        // The mockup's "Big number" role is Sans 200 = Work Sans ExtraLight; its ring/stat thin
        // numerals sit around 300 = Work Sans Light. Both statics are now bundled (instantiated from
        // the OFL variable font), so `.thin`/`.ultraLight` resolve to a genuine 200 and `.light` to a
        // genuine 300 instead of silently flooring at Regular.
        case .thin, .ultraLight: return "WorkSans-ExtraLight"
        case .light: return "WorkSans-Light"
        default: return "WorkSans-Regular"
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
        // Buttons are PILLS in the mockup (radius 999 on a 48pt control = height/2). 24 rather than a
        // huge literal: RoundedRectangle does not clamp an oversized radius gracefully on the older
        // OS floor, and 24 IS the pill for the fixed 48pt control height.
        NoopButtonMetrics.cornerRadius = 24

        // Buttons — the mockup's primary is INK (#16150F), not the fork's sage accent: a flat near-black
        // pill with a warm off-white label. Routed through the package's button override tokens (not the
        // shared `accent`, which many non-button roles read) so only buttons change. The legacy
        // gradient pill (`NoopPrimaryButtonStyle`) takes the same ink via `primaryFlatFill`. Secondary
        // is the mockup's borderless #DED9CC inset with muted #5A564C text.
        NoopButtonPalette.primaryFill    = StrandPalette.textPrimary     // #16150F ink
        NoopButtonPalette.primaryLabel   = StrandPalette.onDarkPrimary   // #F6F3EC warm off-white
        NoopButtonPalette.primaryFlatFill = StrandPalette.textPrimary
        NoopButtonPalette.secondaryFill  = StrandPalette.surfaceInset    // #DED9CC
        NoopButtonPalette.secondaryLabel = Color(hex: "#5A564C")         // mockup's muted secondary text
        // Tertiary/ghost stay on the sage accent — they read as low-emphasis inline links, which the
        // mockup keeps distinct from a filled primary; not overridden here.
    }

    // MARK: - Sky
    //
    // The mockup's sky is ONE elliptical radial gradient per moment — CSS
    // `radial-gradient(132% 86% at X% Y%, …)` — whose off-center hot core IS the light source: it
    // sits upper-right at dawn (76% 2%), upper-center at midday (50% −4%), upper-left at dusk
    // (18% 4%), and the sweep of that core across the top edge is the whole "sun moving" effect.
    // `LiquidSky` renders exactly that when a keyframe carries a `ramp` (see `LiquidSkyStop.ramp`);
    // the four named ramps below are the mockup HTML's own stop lists, colors AND positions, taken
    // verbatim from `sky4` in the reference build. The in-between hours interpolate stop-wise
    // through the same `liquidSkyAt` lerp as before, so the core slides and re-colors continuously.
    // Night has no mockup gradient ("three skies") — it is an invented near-black warm ramp in the
    // same family, flat enough that the glow reads as gone.

    private static func hx(_ hex: UInt32) -> Color {
        Color(.sRGB,
              red: Double((hex >> 16) & 0xff) / 255,
              green: Double((hex >> 8) & 0xff) / 255,
              blue: Double(hex & 0xff) / 255, opacity: 1)
    }

    private static func ramp(_ hexes: [UInt32], _ locs: [Double]) -> [LiquidSkyRampStop] {
        zip(hexes, locs).map { LiquidSkyRampStop(color: hx($0), loc: $1) }
    }

    /// Stop-wise blend of two equal-count ramps (colors and locations both lerp) — used to author
    /// the transition keyframes between the mockup's named moments.
    private static func mix(_ a: [LiquidSkyRampStop], _ b: [LiquidSkyRampStop],
                            _ t: Double) -> [LiquidSkyRampStop] {
        zip(a, b).map { s0, s1 in
            let c0 = s0.color.liquidComponents(), c1 = s1.color.liquidComponents()
            return LiquidSkyRampStop(
                color: Color(.sRGB,
                             red: c0.r + (c1.r - c0.r) * t,
                             green: c0.g + (c1.g - c0.g) * t,
                             blue: c0.b + (c1.b - c0.b) * t, opacity: 1),
                loc: s0.loc + (s1.loc - s0.loc) * t)
        }
    }

    /// A ramped keyframe. `top`/`mid`/`hor` are filled from the ramp (edge / middle / core) purely
    /// as representative colors for any legacy reader — the ramp renderer never touches them.
    private static func skyKey(h: Double, ramp: [LiquidSkyRampStop], x: Double, y: Double,
                               stars: Double) -> LiquidSkyStop {
        var s = LiquidSkyStop(h: h, top: ramp[5].color, mid: ramp[2].color, hor: ramp[0].color,
                              stars: stars, warm: 0)
        s.sunX = x
        s.sunY = y
        s.sunIntensity = 0   // the ramp's own core is the sun; no separate glow disc
        s.ramp = ramp
        return s
    }

    /// The mockup's four skies, verbatim (colors and stop positions from the reference build's CSS).
    /// Dawn ships as 4 stops (0/30/64/100%); it is re-expressed here as 6 stops that lie EXACTLY on
    /// the same ramp (midpoints inserted at 15% and 82%) so every keyframe shares one stop count and
    /// interpolates stop-wise with the 6-stop daylight/dusk/storm ramps.
    private static let dawnRamp = ramp(
        [0xCFB584, 0xA6986C, 0x7E7A55, 0x3E4B3D, 0x323F34, 0x26332C],
        [0, 0.15, 0.30, 0.64, 0.82, 1])
    private static let dayRamp = ramp(
        [0xEDF1DC, 0xB4C596, 0x7B9070, 0x4E6653, 0x33453A, 0x223026],
        [0, 0.14, 0.32, 0.56, 0.78, 1])
    private static let duskRamp = ramp(
        [0xE79C76, 0xB26254, 0x74404A, 0x45303E, 0x281F2C, 0x171320],
        [0, 0.14, 0.32, 0.56, 0.78, 1])
    private static let nightRamp = ramp(
        [0x2A211C, 0x231C18, 0x1C1714, 0x171310, 0x14100D, 0x12100B],
        [0, 0.14, 0.32, 0.56, 0.78, 1])

    private static func applySky() {
        // The core (sunX/sunY) sweeps right-to-left across the day exactly as the mockup's three
        // named centers do — 0.76 at dawn → 0.50 at midday → 0.18 at dusk — with the hours between
        // interpolated so it slides continuously rather than jumping keyframe to keyframe.
        liquidSkyKeys = [
            skyKey(h: 0,    ramp: nightRamp,                  x: 0.50, y: 0.06,  stars: 1),
            skyKey(h: 5,    ramp: mix(nightRamp, dawnRamp, 0.30), x: 0.72, y: 0.08,  stars: 0.5),
            skyKey(h: 6.5,  ramp: dawnRamp,                   x: 0.76, y: 0.02,  stars: 0.15),
            skyKey(h: 8.5,  ramp: mix(dawnRamp, dayRamp, 0.40),  x: 0.70, y: 0.00,  stars: 0),
            skyKey(h: 11,   ramp: mix(dawnRamp, dayRamp, 0.80),  x: 0.58, y: -0.02, stars: 0),
            skyKey(h: 14,   ramp: dayRamp,                    x: 0.50, y: -0.04, stars: 0),
            skyKey(h: 17.5, ramp: mix(dayRamp, duskRamp, 0.65),  x: 0.30, y: 0.01,  stars: 0),
            skyKey(h: 19.5, ramp: duskRamp,                   x: 0.18, y: 0.04,  stars: 0.35),
            skyKey(h: 22,   ramp: mix(duskRamp, nightRamp, 0.80), x: 0.30, y: 0.06,  stars: 0.85),
            skyKey(h: 24,   ramp: nightRamp,                  x: 0.50, y: 0.06,  stars: 1),
        ]
    }

    /// A ONE-OFF sky that is not part of the day cycle: any stop count, explicit ellipse radii and
    /// core position, taken verbatim from a mockup `radial-gradient(RX RY at X Y, …)`. Unlike
    /// `skyKey` (which authors a keyframe on the interpolated day ramp and therefore assumes the
    /// shared 6-stop shape), this builds a standalone stop for a moment the app *triggers* — so it
    /// never has to interpolate with anything and can carry the mockup's own 4 stops. `top`/`mid`/
    /// `hor` are filled from the ramp purely as representative colors for any legacy reader.
    private static func fixedSky(_ hexes: [UInt32], _ locs: [Double],
                                 x: Double, y: Double, rx: Double, ry: Double) -> LiquidSkyStop {
        let r = ramp(hexes, locs)
        var s = LiquidSkyStop(h: 0, top: r[r.count - 1].color, mid: r[r.count / 2].color,
                              hor: r[0].color, stars: 0, warm: 0)
        s.sunX = x
        s.sunY = y
        s.sunIntensity = 0
        s.ramp = r
        s.rampRX = rx
        s.rampRY = ry
        return s
    }

    // MARK: Onboarding skies
    //
    // Onboarding is a first-run narrative, not a time of day: the mockup gives it its OWN warm sky
    // for the whole flow, shifts it green for the single moment the strap bonds, and warms it again
    // for the closing frame. All three are `liquidSkyOverride`-free one-offs (passed explicitly to
    // `LiquidSkyStatic(stop:)`) so they can't be hijacked by, or hijack, the day-cycle sky or the
    // illness alarm override.

    /// The wizard's default sky — the mockup's warm dawn, core upper-right.
    /// `radial-gradient(130% 85% at 76% 6%, #EBCDA6, #C68C70 24%, #6B5760 56%, #241F26)`.
    static let onboardingSky = fixedSky([0xEBCDA6, 0xC68C70, 0x6B5760, 0x241F26],
                                        [0, 0.24, 0.56, 1], x: 0.76, y: 0.06, rx: 1.30, ry: 0.85)

    /// "The one moment the sky shifts green" (the mockup's own annotation): the bonded/connected step.
    /// `radial-gradient(120% 80% at 50% 30%, #7E9A86, #4A6656 30%, #2A3A32 62%, #1B221D)`.
    static let onboardingBondedSky = fixedSky([0x7E9A86, 0x4A6656, 0x2A3A32, 0x1B221D],
                                              [0, 0.30, 0.62, 1], x: 0.50, y: 0.30, rx: 1.20, ry: 0.80)

    /// The closing frame — warmer than the flow's sky, core overhead ("thread complete; sun overhead").
    /// `radial-gradient(130% 90% at 50% 12%, #F0D4AE, #C98F72 26%, #6B5760 58%, #241F26)`.
    static let onboardingDoneSky = fixedSky([0xF0D4AE, 0xC98F72, 0x6B5760, 0x241F26],
                                            [0, 0.26, 0.58, 1], x: 0.50, y: 0.12, rx: 1.30, ry: 0.90)

    /// The mockup's "alarm" sky — replaces the normal time-of-day gradient at the illness ladder's
    /// Major rung (see the call site in `LiquidTodayView`), via `liquidSkyOverride`. The reference
    /// build's own storm gradient, verbatim: `radial-gradient(150% 100% at 74% -8%, #E08A5A 0%,
    /// #C25C38 12%, #94382A 26%, #5E2422 46%, #341A1E 70%, #1C1216 100%)` — orange-to-rust-to-
    /// near-black, a deliberate departure from the calm palette so a real multi-signal anomaly reads
    /// as visually different, not just another card.
    static let alarmSkyStop: LiquidSkyStop = {
        var s = skyKey(h: 0,
                       ramp: ramp([0xE08A5A, 0xC25C38, 0x94382A, 0x5E2422, 0x341A1E, 0x1C1216],
                                  [0, 0.12, 0.26, 0.46, 0.70, 1]),
                       x: 0.74, y: -0.08, stars: 0)
        s.rampRX = 1.50
        s.rampRY = 1.00
        return s
    }()

    // MARK: - Live-workout moment
    //
    // The in-exercise screen is a "moment", not an archive page (the mockup's Handoff sheet: skies
    // belong to Today and to moments), so it gets its own sky and its own on-sky read-out tint. Both
    // live here rather than at the call site so the fork's single override layer still owns every
    // colour value.

    /// The mockup's live-workout sky (section 1e, heart-rate-led take): a dark plum wash under the
    /// whole in-exercise screen. The reference build's own gradient, verbatim —
    /// `radial-gradient(120% 70% at 50% 0%, #4E3B4B 0%, #2E2630 42%, #1B1A14 100%)`. Stops only; the
    /// elliptical core geometry (120% × 70% at 50% 0%) is applied at the single call site, the same
    /// circle-through-a-scaled-context trick `drawRampSky` uses for the Today sky.
    static let liveWorkoutSkyRamp: [LiquidSkyRampStop] =
        ramp([0x4E3B4B, 0x2E2630, 0x1B1A14], [0, 0.42, 1])

    /// Rose read-out tint for content sitting ON a dark Hearth sky. `StrandPalette.metricRose`
    /// (#B4543F) is authored for the warm-paper surfaces and falls to roughly 2.5:1 against the plum
    /// live-workout wash, which is below AA for the big HR numeral it would carry. This is the
    /// mockup's own on-sky rose for the heart-rate hero, the recording dot and the Avg/Peak stats.
    /// On-dark only — nothing on a card surface should reach for it.
    static let onSkyRose = Color(hex: "#E39A9C")
}
