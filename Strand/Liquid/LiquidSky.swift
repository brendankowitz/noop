//  LiquidSky.swift
//  NOOP · Liquid design language
//
//  The time-of-day sky: a gradient that flows continuously through the day's
//  keyframes, a quiet starfield, and two subtle sheets of light. No objects,
//  no blur — clean and crisp, the atmosphere of the app's header.

import SwiftUI
import StrandDesign

/// One stop of a radial sky ramp: a color and its normalized distance from the gradient's center
/// (0 = the hot core, 1 = the outer edge). bknoop fork addition — see `LiquidSkyStop.ramp`.
struct LiquidSkyRampStop {
    let color: Color
    let loc: Double
}

struct LiquidSkyStop {
    let h: Double
    let top: Color, mid: Color, hor: Color
    let stars: Double, warm: Double
    /// Soft light-source position, normalized to the sky rect (0...1; y may go slightly negative to
    /// sit just above the visible frame, like the mockup's own off-canvas radial centers) and
    /// intensity (0 = no glow, matching every upstream keyframe by default). bknoop fork addition —
    /// defaulted so the ten upstream keyframes above don't need touching (see the OVERRIDE POINT note).
    var sunX: Double = 0.5
    var sunY: Double = 0.1
    var sunIntensity: Double = 0
    /// bknoop fork: when non-nil, the sky is ONE elliptical radial gradient — the mockup's own
    /// technique (`radial-gradient(132% 86% at 76% 2%, …)`) — centered at (`sunX`, `sunY`) with these
    /// stops running center → edge, and the legacy vertical bands + `drawSun` glow are not drawn at
    /// all: the ramp's own hot core IS the sun. Every keyframe in an array must carry the same stop
    /// COUNT for interpolation (locations may differ; they lerp too). nil (upstream's default) keeps
    /// the legacy renderer byte-for-byte.
    var ramp: [LiquidSkyRampStop]? = nil
    /// Ellipse radii as fractions of the sky rect's width/height — CSS `radial-gradient(132% 86% …)`.
    var rampRX: Double = 1.32
    var rampRY: Double = 0.86
}

private func hx(_ hex: UInt32) -> Color {
    Color(.sRGB,
          red: Double((hex >> 16) & 0xff) / 255,
          green: Double((hex >> 8) & 0xff) / 255,
          blue: Double(hex & 0xff) / 255, opacity: 1)
}

/// The ten keyframes mirror the real app's day-cycle scenes (SceneHeroBackground),
/// as pure gradients rather than painted art.
///
/// OVERRIDE POINT (bknoop fork): `var`, not `let` — a fork reassigns this whole array once at
/// launch (see `Strand/App/HearthTheme.swift`) to retheme the sky without editing this file, the
/// same override-layer pattern `StrandPalette`/`StrandFont` use. Default values are upstream's.
var liquidSkyKeys: [LiquidSkyStop] = [
    .init(h: 0,    top: hx(0x05060f), mid: hx(0x0b0e22), hor: hx(0x1a1440), stars: 1,   warm: 0),
    .init(h: 5,    top: hx(0x0a0d24), mid: hx(0x1c1a4a), hor: hx(0x4a2a6a), stars: 0.6, warm: 0),
    .init(h: 6.5,  top: hx(0x1b1b4d), mid: hx(0x4a2f7d), hor: hx(0xb0567a), stars: 0.25, warm: 0.2),
    .init(h: 8.5,  top: hx(0x2a4a8f), mid: hx(0x7a5aa0), hor: hx(0xf0a060), stars: 0,   warm: 0.6),
    .init(h: 11,   top: hx(0x2a6ac8), mid: hx(0x5a9ae0), hor: hx(0xa8cef0), stars: 0,   warm: 0.95),
    .init(h: 14,   top: hx(0x2f74d0), mid: hx(0x66a6e8), hor: hx(0xb8d8f4), stars: 0,   warm: 1),
    .init(h: 17.5, top: hx(0x3a4a90), mid: hx(0x9a5a80), hor: hx(0xf0924a), stars: 0,   warm: 0.4),
    .init(h: 19.5, top: hx(0x221c50), mid: hx(0x4a2a70), hor: hx(0x8a4a80), stars: 0.45, warm: 0),
    .init(h: 22,   top: hx(0x070818), mid: hx(0x141335), hor: hx(0x2a1d55), stars: 1,   warm: 0),
    .init(h: 24,   top: hx(0x05060f), mid: hx(0x0b0e22), hor: hx(0x1a1440), stars: 1,   warm: 0),
]

private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
private func lerpColor(_ a: Color, _ b: Color, _ t: Double) -> Color {
    let x = a.liquidComponents(), y = b.liquidComponents()
    return Color(.sRGB, red: lerp(x.r, y.r, t), green: lerp(x.g, y.g, t), blue: lerp(x.b, y.b, t), opacity: 1)
}

/// Set (non-nil) to force the sky to one fixed `LiquidSkyStop` regardless of hour — e.g. the mockup's
/// "alarm" gradient replacing the normal time-of-day sky at the illness ladder's Major rung (see
/// `HearthTheme.alarmSkyStop` and its call site in `LiquidTodayView`). `var`, read fresh by every
/// `liquidSkyAt` call, so toggling it updates every mounted sky (Today + every `ScreenScaffold`
/// scaffold sky) without each needing its own plumbing. nil (the default) is a pure pass-through —
/// zero behavior change for anyone who never sets it.
var liquidSkyOverride: LiquidSkyStop? = nil

func liquidSkyAt(_ hour: Double) -> LiquidSkyStop {
    if let o = liquidSkyOverride { return o }
    var i = 0
    while i < liquidSkyKeys.count - 2 && liquidSkyKeys[i + 1].h <= hour { i += 1 }
    let a = liquidSkyKeys[i], b = liquidSkyKeys[i + 1]
    let t = max(0, min(1, (hour - a.h) / (b.h - a.h)))
    var out = LiquidSkyStop(
        h: hour,
        top: lerpColor(a.top, b.top, t), mid: lerpColor(a.mid, b.mid, t), hor: lerpColor(a.hor, b.hor, t),
        stars: lerp(a.stars, b.stars, t), warm: lerp(a.warm, b.warm, t),
        sunX: lerp(a.sunX, b.sunX, t), sunY: lerp(a.sunY, b.sunY, t),
        sunIntensity: lerp(a.sunIntensity, b.sunIntensity, t))
    // Ramp interpolation is stop-wise (colors AND locations lerp), so the whole gradient — its hot
    // core's hue, where each band sits, and via sunX/sunY above the core's position — slides
    // continuously through the day. Requires equal stop counts on both keys; a mixed nil/non-nil
    // pair (never the case for the fork, which ramps every key) falls back to the legacy fields.
    if let ra = a.ramp, let rb = b.ramp, ra.count == rb.count {
        out.ramp = zip(ra, rb).map {
            LiquidSkyRampStop(color: lerpColor($0.color, $1.color, t), loc: lerp($0.loc, $1.loc, t))
        }
        out.rampRX = lerp(a.rampRX, b.rampRX, t)
        out.rampRY = lerp(a.rampRY, b.rampRY, t)
    }
    return out
}

/// The mockup's sky, drawn the mockup's way: ONE elliptical radial gradient whose off-center hot
/// core is the light source — CSS `radial-gradient(132% 86% at X% Y%, …)` reproduced in Canvas.
/// GraphicsContext only offers a circular radial shading, so the ellipse comes from drawing a circle
/// of radius rxPx through a context scaled by ryPx/rxPx about the center (the center is a fixed
/// point of that transform, so it stays put while the circle squashes to `rxPx × ryPx`). The context
/// is a value copy — the caller's transform is untouched.
private func drawRampSky(_ base: GraphicsContext, ramp: [LiquidSkyRampStop], S: LiquidSkyStop,
                         w: CGFloat, h: CGFloat) {
    let cx = S.sunX * w, cy = S.sunY * h
    let rxPx = max(1, S.rampRX * w), ryPx = max(1, S.rampRY * h)
    var g = base
    g.translateBy(x: cx, y: cy)
    g.scaleBy(x: 1, y: ryPx / rxPx)
    g.translateBy(x: -cx, y: -cy)
    // Oversized in pre-transform space so its image still covers the whole sky after the squash;
    // Canvas clips to its own bounds, so the excess costs nothing.
    let cover = CGRect(x: -w * 2, y: -h * 12, width: w * 5, height: h * 30)
    g.fill(Path(cover),
           with: .radialGradient(
               Gradient(stops: ramp.map { .init(color: $0.color, location: $0.loc) }),
               center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: rxPx))
}

/// The base sky fill, shared by `LiquidSky` and `LiquidSkyStatic`: the fork's single radial ramp
/// when the interpolated stop carries one, else upstream's vertical three-band linear + sun glow.
private func drawSkyBase(_ ctx: inout GraphicsContext, S: LiquidSkyStop, w: CGFloat, h: CGFloat) {
    if let ramp = S.ramp {
        drawRampSky(ctx, ramp: ramp, S: S, w: w, h: h)
    } else {
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)),
                 with: .linearGradient(Gradient(stops: [
                    .init(color: S.top, location: 0),
                    .init(color: S.mid, location: 0.5),
                    .init(color: S.hor, location: 0.9)]),
                                       startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)))
        drawSun(&ctx, sunX: S.sunX, sunY: S.sunY, intensity: S.sunIntensity, w: w, h: h)
    }
}

/// The soft light-source glow (bknoop fork addition): a large, soft radial wash centered at the
/// interpolated sun position, drawn once right after the base gradient fill so stars and the settle
/// fade layer on top of it. Continuous with the same lerp everything else in the sky uses — as the
/// hour advances the glow slides and brightens/dims exactly like the gradient it sits on, rather than
/// popping between fixed per-keyframe positions.
private func drawSun(_ ctx: inout GraphicsContext, sunX: Double, sunY: Double, intensity: Double,
                      w: CGFloat, h: CGFloat) {
    guard intensity > 0.01 else { return }
    let center = CGPoint(x: sunX * w, y: sunY * h)
    let radius = max(w, h) * 0.65
    let glow = Color.white.opacity(0.22 * intensity)
    ctx.fill(
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
        with: .radialGradient(Gradient(colors: [glow, glow.opacity(0)]), center: center, startRadius: 0, endRadius: radius)
    )
}

/// A precomputed quiet star field (positions fixed; only the count that render
/// depends on how starry the hour is).
private struct LiquidStar { let x, y, z, ph, sp: Double }
private let liquidStars: [LiquidStar] = (0..<70).map { _ in
    LiquidStar(x: .random(in: 0...1), y: .random(in: 0...0.78), z: .random(in: 0...1),
               ph: .random(in: 0..<7), sp: 0.2 + .random(in: 0..<0.5))
}

struct LiquidSky: View {
    /// Hour of day 0...24. Defaults to live time when nil.
    var hour: Double?
    /// How fully the sky dissolves into the canvas at the bottom (1 = the default seamless fade; <1 holds
    /// the atmosphere so the sky still reads under a full-height "sky behind cards" backdrop).
    var settleStrength: Double = 1
    /// The call site already swaps in `LiquidSkyStatic` when motion is unwanted, but this view carried
    /// no gate of its own — a second call site would have been silently ungated. `paused:` makes the
    /// frame loop stand down from inside, so the gate travels with the view.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var motion = NoopMotionState.shared

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0,
                                paused: motion.poseStill(reduceMotion))) { tl in
            let now = liquidSeconds(tl.date)
            let h = hour ?? liveHour()
            // The sky must dissolve into the SAME canvas colour the body uses, so there is no hard seam
            // where the sky meets the page. Reads the actual token (not a hardcoded RGB literal aping
            // it, which is what this did before and is exactly why a retheme's new surfaceBase used to
            // seam against it) — Canvas resolves a dynamic `Color(light:dark:)` fill against its own
            // environment, the same as any other SwiftUI Color, so no manual light/dark branch is needed.
            let settle = StrandPalette.surfaceBase
            Canvas { ctx, size in
                render(ctx, size, hour: h, now: now, settle: settle)
            }
        }
    }

    private func liveHour() -> Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
    }

    private func render(_ base: GraphicsContext, _ size: CGSize, hour: Double, now: Double,
                        settle: Color) {
        let S = liquidSkyAt(hour)
        let w = size.width, h = size.height
        var ctx = base
        // the gradient IS the scene
        drawSkyBase(&ctx, S: S, w: w, h: h)
        // slow breath of light low in the sky
        let breathe = 0.5 + 0.5 * sin(now * 0.22)
        ctx.fill(Path(CGRect(x: 0, y: h * 0.45, width: w, height: h * 0.55)),
                 with: .linearGradient(Gradient(colors: [.white.opacity(0), .white.opacity(0.05 + breathe * 0.03)]),
                                       startPoint: CGPoint(x: 0, y: h * 0.45), endPoint: CGPoint(x: 0, y: h)))
        // The warm bottom wash belongs to the legacy cool-blue bands; a radial ramp already carries
        // its own warmth, and tinting it would pull the mockup's measured colors off.
        if S.ramp == nil, S.warm > 0.01 {
            let warm = Color(.sRGB, red: 1, green: 200/255, blue: 120/255, opacity: 1)
            ctx.fill(Path(CGRect(x: 0, y: h * 0.55, width: w, height: h * 0.45)),
                     with: .linearGradient(Gradient(colors: [warm.opacity(0), warm.opacity(S.warm * 0.10)]),
                                           startPoint: CGPoint(x: 0, y: h * 0.55), endPoint: CGPoint(x: 0, y: h)))
        }
        // stars
        if S.stars > 0.01 {
            for s in liquidStars {
                let baseA = 0.04 + s.z * 0.16
                let tw = pow(max(0, sin(s.ph + now * s.sp)), 6)
                let o = S.stars * (baseA + tw * 0.28)
                if o < 0.02 { continue }
                let sz = 0.6 + s.z * 0.8
                ctx.fill(Path(CGRect(x: s.x * w, y: s.y * h, width: sz, height: sz)), with: .color(.white.opacity(o)))
            }
        }
        // Settle into the page: a long fade to the theme's surfaceBase over the lower half so the sky
        // dissolves seamlessly into the body — no hard cut (the light-mode dark→white slam is gone).
        ctx.fill(Path(CGRect(x: 0, y: h * 0.45, width: w, height: h * 0.55)),
                 with: .linearGradient(Gradient(colors: [settle.opacity(0), settle.opacity(settleStrength)]),
                                       startPoint: CGPoint(x: 0, y: h * 0.45), endPoint: CGPoint(x: 0, y: h)))
    }
}

/// A subtle full-bleed time-of-day sky for any `ScreenScaffold.topBackground`, so the liquid
/// atmosphere carries across EVERY tab. Same live sky as Today at a modest header height, so the
/// charts/cards below sit on the dark canvas — the redesign's "the options change, not the page"
/// feel. Non-interactive + accessibility-hidden (pure decoration).
///
/// Honours the SAME two Appearance gates as Today and the metric-detail screens, so every scaffold
/// that passes this reads them for free (Trends / Sleep / More / the hub screens previously ignored
/// both — the sky stayed a fixed band there while Today filled the viewport):
/// - "Day-cycle background" OFF renders nothing, leaving the scaffold's plain `surfaceBase` canvas
///   (the same visual as passing no topBackground at all).
/// - "Sky behind cards" ON fills the scaffold's whole backdrop (the ZStack already spans the scroll
///   view; only this frame capped it) with the held-atmosphere settle, so the Card-transparency
///   setting reveals the sky under every card — the LiquidTodayView treatment.
/// A real View (not a one-shot read) so @AppStorage keeps it reactive: toggling either setting
/// updates every mounted tab in place. Mirrors the Android `LiquidScreenSky(fillHeight:)` +
/// `fullBleedBackground` pairing.
struct LiquidScaffoldSky: View {
    var height: CGFloat = 240
    @AppStorage(SceneBackgroundPrefs.enabledKey) private var showDayCycleBackground = true

    var body: some View {
        // The Hearth sheet layout ALWAYS has a header band (white kicker/serif text sits on it), so
        // "Day-cycle background" OFF now swaps the sky for the mockup's flat ink rather than removing
        // the band entirely — bare cream under white text would be unreadable. Full-bleed either way;
        // the opaque sheet covers everything below the band, so "sky behind cards" no longer applies.
        Group {
            if showDayCycleBackground {
                LiquidSkyStatic(hour: nil, settleStrength: 1)
            } else {
                FlatInkFill()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The flat `#1B1A14` header-band fill with the standard settle fade into the page surface — shared
/// by `LiquidFlatInkBackground` (the archive screens' scaffold) and `LiquidScaffoldSky`'s
/// day-cycle-off fallback.
private struct FlatInkFill: View {
    var body: some View {
        ZStack(alignment: .top) {
            liquidFlatInkColor
            LinearGradient(
                colors: [StrandPalette.surfaceBase.opacity(0), StrandPalette.surfaceBase],
                startPoint: UnitPoint(x: 0.5, y: 0.45), endPoint: UnitPoint(x: 0.5, y: 1.0)
            )
        }
    }
}

func liquidScaffoldSky(height: CGFloat = 240) -> AnyView {
    AnyView(LiquidScaffoldSky(height: height))
}

/// bknoop fork addition, per the mockup's own "Handoff" reference sheet: "Skies belong to Today and
/// to moments [Sleep]. Food, Trends and Health use flat ink instead — that is how you know which half
/// of the app you are in." A flat `#1B1A14` fill, same frame/height/settle-fade shape as
/// `LiquidScaffoldSky` so it drops into the exact same `topBackground:` slot, for the screens that are
/// archive/reference rather than a lived moment.
// Internal (not private): LiquidTodayView paints the same flat ink behind its sky block when the
// day-cycle background is toggled off, so the hero's white-on-sky text stays readable.
let liquidFlatInkColor = Color(.sRGB, red: 0x1B / 255, green: 0x1A / 255, blue: 0x14 / 255, opacity: 1)

struct LiquidFlatInkBackground: View {
    var height: CGFloat = 240

    var body: some View {
        // Static ink — nothing here animates, so the "Day-cycle background" pref no longer removes it
        // (the sheet layout's white header text needs the band; see LiquidScaffoldSky). Full-bleed;
        // the opaque sheet covers everything below the band.
        FlatInkFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

func liquidFlatInkBackground(height: CGFloat = 240) -> AnyView {
    AnyView(LiquidFlatInkBackground(height: height))
}

/// A STATIC time-of-day sky, rendered ONCE (no TimelineView → CoreAnimation caches it as a stable layer,
/// zero per-frame cost) for the scaffold backgrounds on the chart-heavy tabs. An always-animating Canvas
/// behind the charts stole frame headroom and caused stutter (2026-07-02); this is the same look
/// minus the twinkle/breath, matching the classic app's static scene image for scroll perf.
struct LiquidSkyStatic: View {
    var hour: Double?
    /// See `LiquidSky.settleStrength` — 1 = default seamless fade; <1 holds the atmosphere for the
    /// full-height "sky behind cards" backdrop.
    var settleStrength: Double = 1
    /// bknoop fork: render THIS stop instead of resolving the hour on the day cycle. For skies the app
    /// *triggers* rather than schedules — onboarding's warm/green/closing moments (`HearthTheme
    /// .onboardingSky` & friends) — which must neither read `liquidSkyOverride` nor set it (that
    /// global belongs to the illness alarm and would leak across every mounted sky). nil (the default)
    /// is the exact prior behaviour.
    var stop: LiquidSkyStop? = nil

    var body: some View {
        let h = hour ?? liveHour()
        // Reads the actual token — see the identical fix + rationale in `LiquidSky.body` above.
        let settle = StrandPalette.surfaceBase
        Canvas { ctx, size in
            let S = stop ?? liquidSkyAt(h)
            let w = size.width, hh = size.height
            drawSkyBase(&ctx, S: S, w: w, h: hh)
            if S.stars > 0.01 {
                for s in liquidStars {
                    let o = S.stars * (0.04 + s.z * 0.16)
                    if o < 0.02 { continue }
                    let sz = 0.6 + s.z * 0.8
                    ctx.fill(Path(CGRect(x: s.x * w, y: s.y * hh, width: sz, height: sz)),
                             with: .color(.white.opacity(o)))
                }
            }
            ctx.fill(Path(CGRect(x: 0, y: hh * 0.45, width: w, height: hh * 0.55)),
                     with: .linearGradient(Gradient(colors: [settle.opacity(0), settle.opacity(settleStrength)]),
                                           startPoint: CGPoint(x: 0, y: hh * 0.45), endPoint: CGPoint(x: 0, y: hh)))
        }
    }

    private func liveHour() -> Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
    }
}
