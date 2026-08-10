//  LiquidSky.swift
//  NOOP · Liquid design language
//
//  The time-of-day sky: a gradient that flows continuously through the day's
//  keyframes, a quiet starfield, and two subtle sheets of light. No objects,
//  no blur — clean and crisp, the atmosphere of the app's header.

import SwiftUI
import StrandDesign

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

func liquidSkyAt(_ hour: Double) -> (top: Color, mid: Color, hor: Color, stars: Double, warm: Double,
                                      sunX: Double, sunY: Double, sunIntensity: Double) {
    if let o = liquidSkyOverride {
        return (o.top, o.mid, o.hor, o.stars, o.warm, o.sunX, o.sunY, o.sunIntensity)
    }
    var i = 0
    while i < liquidSkyKeys.count - 2 && liquidSkyKeys[i + 1].h <= hour { i += 1 }
    let a = liquidSkyKeys[i], b = liquidSkyKeys[i + 1]
    let t = max(0, min(1, (hour - a.h) / (b.h - a.h)))
    return (lerpColor(a.top, b.top, t), lerpColor(a.mid, b.mid, t), lerpColor(a.hor, b.hor, t),
            lerp(a.stars, b.stars, t), lerp(a.warm, b.warm, t),
            lerp(a.sunX, b.sunX, t), lerp(a.sunY, b.sunY, t), lerp(a.sunIntensity, b.sunIntensity, t))
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
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: h)),
                 with: .linearGradient(Gradient(stops: [
                    .init(color: S.top, location: 0),
                    .init(color: S.mid, location: 0.5),
                    .init(color: S.hor, location: 0.9)]),
                                       startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: h)))
        drawSun(&ctx, sunX: S.sunX, sunY: S.sunY, intensity: S.sunIntensity, w: w, h: h)
        // slow breath of light low in the sky
        let breathe = 0.5 + 0.5 * sin(now * 0.22)
        ctx.fill(Path(CGRect(x: 0, y: h * 0.45, width: w, height: h * 0.55)),
                 with: .linearGradient(Gradient(colors: [.white.opacity(0), .white.opacity(0.05 + breathe * 0.03)]),
                                       startPoint: CGPoint(x: 0, y: h * 0.45), endPoint: CGPoint(x: 0, y: h)))
        if S.warm > 0.01 {
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
    @AppStorage(SkyBehindCardsPrefs.enabledKey) private var skyBehindCards = true

    var body: some View {
        if showDayCycleBackground {
            LiquidSkyStatic(hour: nil, settleStrength: skyBehindCards ? 0.78 : 1)
                .frame(maxWidth: .infinity, maxHeight: skyBehindCards ? .infinity : nil)
                .frame(height: skyBehindCards ? nil : height, alignment: .top)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
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
private let liquidFlatInkColor = Color(.sRGB, red: 0x1B / 255, green: 0x1A / 255, blue: 0x14 / 255, opacity: 1)

struct LiquidFlatInkBackground: View {
    var height: CGFloat = 240
    @AppStorage(SceneBackgroundPrefs.enabledKey) private var showDayCycleBackground = true
    @AppStorage(SkyBehindCardsPrefs.enabledKey) private var skyBehindCards = true

    var body: some View {
        if showDayCycleBackground {
            // Same two-layer settle technique LiquidSkyStatic uses (flat fill + a separate transparent
            // -> opaque settle-color fade on top), just without a Canvas — flat ink has no stars/sun/
            // animation to justify one. `UnitPoint` fractions are relative to this view's own bounds,
            // matching the Canvas version's `h * 0.45 ... h` band without needing pixel geometry.
            let settle = StrandPalette.surfaceBase
            let settleStrength = skyBehindCards ? 0.78 : 1.0
            ZStack(alignment: .top) {
                liquidFlatInkColor
                LinearGradient(
                    colors: [settle.opacity(0), settle.opacity(settleStrength)],
                    startPoint: UnitPoint(x: 0.5, y: 0.45), endPoint: UnitPoint(x: 0.5, y: 1.0)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: skyBehindCards ? .infinity : nil)
            .frame(height: skyBehindCards ? nil : height, alignment: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
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

    var body: some View {
        let h = hour ?? liveHour()
        // Reads the actual token — see the identical fix + rationale in `LiquidSky.body` above.
        let settle = StrandPalette.surfaceBase
        Canvas { ctx, size in
            let S = liquidSkyAt(h)
            let w = size.width, hh = size.height
            ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: hh)),
                     with: .linearGradient(Gradient(stops: [
                        .init(color: S.top, location: 0),
                        .init(color: S.mid, location: 0.5),
                        .init(color: S.hor, location: 0.9)]),
                                           startPoint: CGPoint(x: 0, y: 0), endPoint: CGPoint(x: 0, y: hh)))
            drawSun(&ctx, sunX: S.sunX, sunY: S.sunY, intensity: S.sunIntensity, w: w, h: hh)
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
