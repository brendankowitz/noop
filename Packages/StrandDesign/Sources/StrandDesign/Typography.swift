import SwiftUI

// MARK: - Strand Typography (§9.2)
//
// Helvetica Neue everywhere (Titanium & Gold): a precise, mechanical grotesque
// in place of the old rounded face. Tabular/monospaced digits on every numeric
// role so live values don't reflow. SF Mono stays for raw/log views. Overline =
// sparing ALL-CAPS w/ wide tracking.
//
// All numeric styles use `.monospacedDigit()` so live values don't reflow.
//
// OVERRIDE POINT (bknoop fork): `family` is a settable `var`, and every role below reads it live
// (no role is a `let` computed once at first access) so a fork can reassign `family` — and add a
// serif `voice` role — once at launch (see `Strand/App/HearthTheme.swift`) with no edits here.

public enum StrandFont {

    // MARK: Family

    /// The house family. Defaults to Helvetica Neue, a built-in system face; a fork may reassign
    /// this to a bundled family at launch. Every role reads this live, never caches it, so an
    /// override set before first render applies everywhere with no other change needed.
    public static var family = "Helvetica Neue"

    /// A second, occasional family for the one "voice" role (a short narrative sentence) — independent
    /// of `family` so a themed voice can go serif even while `family` stays a sans grotesque. Defaults
    /// to the same system face as `family` until a fork points it elsewhere.
    public static var voiceFamily = "Helvetica Neue"

    /// Optional resolver override: when set, produces the exact Font for a given size/weight/optional
    /// text-style instead of the default `Font.custom(family, size:).weight(weight)` composition.
    /// Needed when a bundled family registers each weight under ITS OWN family/PostScript name (the
    /// common shape of a static, non-variable font export) — `.weight()` can only find a sibling face
    /// within the SAME family, so it silently fails to pick up e.g. a Medium or SemiBold shipped as
    /// a distinct family. A fork sets this once at launch alongside `family`; nil (the default)
    /// preserves the exact system-font behavior this file always had.
    public static var resolveFamily: ((_ size: CGFloat, _ weight: Font.Weight, _ style: Font.TextStyle?) -> Font)?

    /// Same idea as `resolveFamily`, for the `voice` role's `voiceFamily`/light weight.
    public static var resolveVoiceFamily: ((_ size: CGFloat, _ style: Font.TextStyle?) -> Font)?

    /// Helvetica Neue at a FIXED size/weight — used by the big gauge/tile numerals (`display`,
    /// `rounded`, `number`) that live in fixed-geometry rings/tiles where unbounded growth would
    /// overflow. Prose and inline-number roles use `helveticaScaled` instead.
    private static func helvetica(_ size: CGFloat, weight: Font.Weight) -> Font {
        resolveFamily?(size, weight, nil) ?? .custom(family, size: size).weight(weight)
    }

    /// Like `helvetica`, but the size SCALES with the user's Dynamic Type / Larger Text setting,
    /// anchored to a matching text style. The plain `.custom(_:size:)` overload produces a FROZEN
    /// point size, so every prose/label role used to ignore Dynamic Type entirely — this routes them
    /// through `.custom(_:size:relativeTo:)` so they scale (available on the iOS 16 / macOS 13 floor).
    private static func helveticaScaled(_ size: CGFloat, weight: Font.Weight,
                                        relativeTo style: Font.TextStyle) -> Font {
        resolveFamily?(size, weight, style) ?? .custom(family, size: size, relativeTo: style).weight(weight)
    }

    // MARK: Scale (§9.2)

    /// OVERRIDE POINT (bknoop fork): the "big number" weight — upstream's gauge/hero numeral is bold;
    /// the Hearth mockup's equivalent role ("Big number — Sans 200, 54/−0.04em") is a thin numeral
    /// instead. A `var` so a fork can dial the weight without hardcoding a new value into `display()`.
    public static var displayWeight: Font.Weight = .bold

    /// Display 64–80 / `displayWeight` — the gauge score number. Helvetica Neue with tight
    /// tracking (≈ -0.04em), tabular digits so a changing value never reflows.
    public static func display(_ size: CGFloat = 72) -> Font {
        helvetica(size, weight: displayWeight).monospacedDigit()
    }

    /// The tight tracking for big display numbers (≈ -0.04em). Apply alongside
    /// `display(_:)` at the use site, e.g. `.tracking(StrandFont.displayTracking(72))`.
    public static func displayTracking(_ size: CGFloat = 72) -> CGFloat {
        -size * 0.04
    }

    /// A Helvetica-Neue numeric style at an arbitrary size/weight — the house
    /// numeral. Tabular so live values align. Use anywhere a score/number is shown.
    public static func rounded(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        helvetica(size, weight: weight).monospacedDigit()
    }

    /// Title1 28 / Bold. Scales with Dynamic Type. (`var`, not `let` — reads `family` live so a
    /// fork's override applies even if this role was touched before the override ran.)
    public static var title1: Font { helveticaScaled(28, weight: .bold, relativeTo: .title) }

    /// Title2 22 / Semibold. Scales with Dynamic Type.
    public static var title2: Font { helveticaScaled(22, weight: .semibold, relativeTo: .title2) }

    /// Headline 17 / Semibold. Scales with Dynamic Type.
    public static var headline: Font { helveticaScaled(17, weight: .semibold, relativeTo: .headline) }

    /// Body 15 / Regular. Scales with Dynamic Type.
    public static var body: Font { helveticaScaled(15, weight: .regular, relativeTo: .body) }

    /// Subhead 13. Scales with Dynamic Type.
    public static var subhead: Font { helveticaScaled(13, weight: .regular, relativeTo: .subheadline) }

    /// Caption 12. Scales with Dynamic Type.
    public static var caption: Font { helveticaScaled(12, weight: .regular, relativeTo: .caption) }

    /// Footnote 11. Scales with Dynamic Type.
    public static var footnote: Font { helveticaScaled(11, weight: .regular, relativeTo: .footnote) }

    /// Overline 11 / Bold, +1.4 tracking (apply `.tracking(1.4)` at use site;
    /// `overlineText(_:)` does it for you). Sparing ALL-CAPS labels. Scales with Dynamic Type.
    public static var overline: Font { helveticaScaled(11, weight: .bold, relativeTo: .caption2) }

    /// The one narrative-sentence role — a short "voice" line per screen, set in `voiceFamily`
    /// (defaults to `family`) at LIGHT weight. Scales with Dynamic Type against `.title2` (the voice
    /// sentence is display-sized, not body-sized). Distinct from every other role, which stays in
    /// `family` — the voice is meant to read as a second, occasional register, not the house face.
    public static func voice(_ size: CGFloat = 25, relativeTo style: Font.TextStyle = .title2) -> Font {
        resolveVoiceFamily?(size, style) ?? .custom(voiceFamily, size: size, relativeTo: style).weight(.light)
    }

    /// `overline` at a custom point size — same Helvetica face, weight and Dynamic-Type scaling
    /// (relativeTo `.caption2`), just smaller. Passing 11 returns exactly `.overline`. Lets a caller
    /// shrink an ALL-CAPS label to fit a small container without losing accessibility text-scaling.
    public static func overlineScaled(_ size: CGFloat) -> Font {
        helveticaScaled(size, weight: .bold, relativeTo: .caption2)
    }

    /// Mono 13 (SF Mono) — raw / log views. Tabular by nature.
    public static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)

    // MARK: Numeric variants (tabular digits)

    /// A numeric style at an arbitrary size/weight, for live values — Helvetica
    /// Neue, tabular digits. This is the tile/value numeral.
    public static func number(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        helvetica(size, weight: weight).monospacedDigit()
    }

    /// House-family body number — for inline live values that should align. Scales with Dynamic
    /// Type alongside its sibling `body`/`caption` labels so a value and its label stay matched.
    public static var bodyNumber: Font { helveticaScaled(15, weight: .medium, relativeTo: .body).monospacedDigit() }

    /// House-family caption number — for small live values (sparklines, chips). Scales with Dynamic Type.
    public static var captionNumber: Font { helveticaScaled(12, weight: .medium, relativeTo: .caption).monospacedDigit() }

    /// Mono at an arbitrary size.
    public static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// The recommended tracking for overline text (wide ALL-CAPS labels, ≈ 0.13em).
    public static let overlineTracking: CGFloat = 1.4
}

// MARK: - Text helpers

public extension Text {
    /// Style as an overline label: ALL-CAPS, bold, +1.4 tracking, tertiary text.
    func strandOverline() -> some View {
        self.font(StrandFont.overline)
            .tracking(StrandFont.overlineTracking)
            .textCase(.uppercase)
            .foregroundStyle(StrandPalette.textSecondary)
    }
}

public extension View {
    /// Convenience: an overline-styled label string.
    static func strandOverline(_ string: String) -> some View {
        Text(string).strandOverline()
    }
}

#if DEBUG
#Preview("Typography") {
    ScrollView {
        VStack(alignment: .leading, spacing: 18) {
            Text("88").font(StrandFont.display(72)).tracking(StrandFont.displayTracking(72)).foregroundStyle(StrandPalette.textPrimary)
            Text("Title 1 / Bold 28").font(StrandFont.title1).foregroundStyle(StrandPalette.textPrimary)
            Text("Title 2 / Semibold 22").font(StrandFont.title2).foregroundStyle(StrandPalette.textPrimary)
            Text("Headline / Semibold 17").font(StrandFont.headline).foregroundStyle(StrandPalette.textPrimary)
            Text("Body / Regular 15 — the thread of you, read in full.")
                .font(StrandFont.body).foregroundStyle(StrandPalette.textPrimary)
            Text("Subhead 13").font(StrandFont.subhead).foregroundStyle(StrandPalette.textSecondary)
            Text("Caption 12").font(StrandFont.caption).foregroundStyle(StrandPalette.textSecondary)
            Text("Footnote 11").font(StrandFont.footnote).foregroundStyle(StrandPalette.textTertiary)
            Text("Overline").strandOverline()
            Text("0xAA 41 00 1c crc32=f3a1  mono 13").font(StrandFont.mono).foregroundStyle(StrandPalette.textSecondary)
            HStack(spacing: 4) {
                Text("HRV").font(StrandFont.caption).foregroundStyle(StrandPalette.textSecondary)
                Text("62").font(StrandFont.bodyNumber).foregroundStyle(StrandPalette.textPrimary)
                Text("ms").font(StrandFont.caption).foregroundStyle(StrandPalette.textTertiary)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(width: 520, height: 620)
    .background(StrandPalette.surfaceBase)
    .preferredColorScheme(.dark)
}
#endif
