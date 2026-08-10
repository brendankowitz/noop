//  LiquidSyncStatus.swift
//  NOOP · Hearth design — the sky's ambient sync status line (mockup 7b) and the sync page it
//  opens (mockup 7c).
//
//  7b: a slim status line in the Today sky, between the header row and the ring rail. It has
//  exactly one of four states — syncing (spinner + "Reading the strap · N chunks"), live
//  (breathing dot + "Live · NN bpm"), a TRANSIENT "Up to date" that collapses after a few
//  seconds, or hidden (zero pixels). All states resolve from the app's one sync-state seam
//  (`SyncChipState.resolve(live:)`, #245) — nothing here invents a new signal. Honesty rules from
//  the mockup: chunk counts only, never a percent (total pending is unknowable from the protocol);
//  no number ever animates toward a value; nothing announces success beyond the quiet collapse.
//
//  7c: tapping the line lands on `SyncPageView` — flat ink ("a record of a device, not a
//  moment"), built from the six-card vocabulary. The mockup's per-category "Coming across" rows
//  (sleep stages / HRV / respiratory…) are illustrative fiction: NOOP's offload pipeline knows THAT
//  a drain is running and how many chunks it has pulled, not which physiological category each
//  chunk carries — so the page shows the single honest "Strap history" row instead, plus the
//  real Device facts LiveState already carries.

import SwiftUI
import StrandDesign

// MARK: - Display resolution

/// What the sky's sync line shows. Distinct from `SyncChipState`: the chip's steady `.synced`
/// state is deliberately NOT an ambient line state — per the mockup's rules the line only says
/// "Up to date" transiently after a sync finishes, then collapses ("nothing announces success").
enum SyncLineDisplay: Equatable {
    case syncing(chunks: Int)
    case live(bpm: Int?)
    case upToDate          // transient — auto-collapses
    case hidden
}

#if DEBUG
/// Screenshot harness for the sync line + page (the `DemoDayHarness` pattern): `--demo-sync
/// syncing|live|synced` pins the display so the states can be captured in the simulator, where no
/// real strap ever backfills. Whole-file DEBUG; `pinned == nil` (no arg) changes nothing.
enum SyncLineDemo {
    static let pinned: SyncLineDisplay? = {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--demo-sync"), args.index(after: i) < args.endIndex
        else { return nil }
        switch args[args.index(after: i)] {
        case "syncing": return .syncing(chunks: 3)
        case "live":    return .live(bpm: 58)
        case "synced":  return .upToDate
        default:        return nil
        }
    }()
}
#endif

// MARK: - 7b · The sync status line

/// The ambient sync line. Owns LiveState (isolated leaf, per LiquidTodayView's convention) so the
/// per-chunk `backfilling` publishes re-render only this line, never the whole Today.
///
/// Debounce: `live.backfilling` flickers false between EVERY offload chunk (exitBackfilling at
/// each HISTORY_END → auto-continue re-kick), with a real BLE round-trip gap in between — the same
/// strobe `LiquidRefreshIndicator` used to ride out. The line goes visible instantly, but only
/// leaves the syncing state after 3s with no new chunk; that also means the spinner keeps turning
/// briefly after the true last chunk (the protocol cannot distinguish "gap" from "done" sooner —
/// the mockup's "stops the instant the last chunk lands" is approximated as tightly as the wire
/// allows). Then "Up to date" holds for a few seconds and collapses.
struct LiquidSyncLine: View {
    /// The 8c revealed-slot variant: a slimmer inline icon+text row for every state (the mockup's
    /// own held-state specimen); the ambient sky placement uses the 7b column layout for syncing.
    var inline: Bool = false
    /// Applied around VISIBLE content only, so the hidden state truly costs zero pixels even
    /// inside a spacing-0 host.
    var topPadding: CGFloat = 0

    @EnvironmentObject private var live: LiveState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var motion = NoopMotionState.shared
    private var poseStill: Bool { motion.poseStill(reduceMotion) }

    @State private var syncing = false          // debounced backfilling
    @State private var showUpToDate = false     // transient post-sync state
    @State private var hideTask: Task<Void, Never>?
    @State private var collapseTask: Task<Void, Never>?

    private var display: SyncLineDisplay {
        #if DEBUG
        if let pinned = SyncLineDemo.pinned { return pinned }
        #endif
        if syncing { return .syncing(chunks: live.syncChunksThisSession) }
        if showUpToDate { return .upToDate }
        // The persistent "Live" state is the 5/MG whose history sync is experimental — live HR is
        // the only sync there IS, so the line says so (same case the header chip called "✓ live").
        if SyncChipState.resolve(live: live) == .experimentalLive {
            let hr = live.heartRate
            return .live(bpm: (hr ?? 0) > 0 ? hr : nil)
        }
        return .hidden
    }

    var body: some View {
        Group {
            switch display {
            case .hidden:
                EmptyView()
            case .syncing(let chunks):
                link(label: syncingA11y(chunks)) {
                    if inline {
                        HStack(spacing: 9) {
                            SyncSpinnerIcon(size: 13, still: poseStill)
                            Text(syncingText(chunks))
                                .font(.system(size: 12.5))
                                .foregroundStyle(.white.opacity(0.75))
                                .breathing(still: poseStill)
                        }
                    } else {
                        // The mockup's 7b specimen: 26pt spinner above the breathing text.
                        VStack(spacing: 11) {
                            SyncSpinnerIcon(size: 20, still: poseStill)
                            Text(syncingText(chunks))
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.78))
                                .breathing(still: poseStill)
                        }
                    }
                }
            case .live(let bpm):
                link(label: liveA11y(bpm)) {
                    HStack(spacing: 9) {
                        Circle().fill(StrandPalette.chargeBright)
                            .frame(width: 7, height: 7)
                            .breathing(still: poseStill, period: 1.6)
                        Text(bpm.map { String(localized: "Live · \($0) bpm") } ?? String(localized: "Live"))
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.82))
                    }
                }
            case .upToDate:
                link(label: String(localized: "Strap history up to date")) {
                    HStack(spacing: 9) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Up to date")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .onAppear { syncing = live.backfilling }
        .onChangeCompat(of: live.backfilling) { raw in
            hideTask?.cancel()
            if raw {
                collapseTask?.cancel()
                withAnimation(.easeOut(duration: 0.25)) { syncing = true; showUpToDate = false }
            } else {
                // Might just be the gap between two chunks — ride it out; a new chunk cancels this.
                hideTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.3)) { syncing = false; showUpToDate = true }
                    collapseTask?.cancel()
                    collapseTask = Task { @MainActor in
                        // "Reads 'Up to date' for a few seconds and then collapses."
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        if !Task.isCancelled {
                            withAnimation(.easeOut(duration: 0.35)) { showUpToDate = false }
                        }
                    }
                }
            }
        }
    }

    /// The whole line is one tap target → the sync page. Value-based: the first hop off the Today
    /// root must ride the tab's NavigationPath so a Today re-tap can pop it (#198, TabRoute).
    private func link(label: String, @ViewBuilder content: () -> some View) -> some View {
        NavigationLink(value: TabRoute.syncStatus) {
            content()
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, topPadding)
        .accessibilityLabel(label)
        .accessibilityHint(Text("Opens the sync page"))
        .transition(.opacity)
    }

    /// Honest phrasing: chunks PULLED so far — the strap never says how many remain, so the
    /// mockup's "N chunks left" cannot be said truthfully. Zero chunks stays wordless progress.
    private func syncingText(_ chunks: Int) -> String {
        chunks > 0 ? String(localized: "Reading the strap · \(chunks) chunks")
                   : String(localized: "Reading the strap")
    }
    private func syncingA11y(_ chunks: Int) -> String {
        chunks > 0 ? String(localized: "Syncing strap history, \(chunks) chunks pulled")
                   : String(localized: "Syncing strap history")
    }
    private func liveA11y(_ bpm: Int?) -> String {
        bpm.map { String(localized: "Live heart rate \($0) beats per minute") }
            ?? String(localized: "Live heart rate")
    }
}

// MARK: - Motion primitives (the mockup's three motions, gated on reduce-motion)

/// The mockup's Rotate motion: 1.1s linear, continuous, only ever inside the small spinner icon.
private struct SyncSpinnerIcon: View {
    var size: CGFloat
    var tint: Color = .white.opacity(0.9)
    var still: Bool
    @State private var spinning = false

    var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: size, weight: .regular))
            .foregroundStyle(tint)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .onAppear {
                guard !still else { return }
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    spinning = true
                }
            }
            .accessibilityHidden(true)
    }
}

/// The mockup's Breathe motion: 1.6–1.8s, OPACITY only (never scale). Gated: reduce-motion (and
/// the in-app quiet toggle / low power) hold the content at full opacity.
private struct BreathingModifier: ViewModifier {
    var still: Bool
    var period: Double
    @State private var dim = false

    func body(content: Content) -> some View {
        content
            .opacity(still ? 1 : (dim ? 0.45 : 1))
            .onAppear {
                guard !still else { return }
                withAnimation(.easeInOut(duration: period).repeatForever(autoreverses: true)) {
                    dim = true
                }
            }
    }
}

private extension View {
    func breathing(still: Bool, period: Double = 1.8) -> some View {
        modifier(BreathingModifier(still: still, period: period))
    }
}

// MARK: - 7c · The sync page

/// The destination behind the 7b line. Flat ink (the app's "records/archives" background — this is
/// a record of a device, not a moment), one honest "Coming across" card, the Device facts LiveState
/// really carries, and — while a sync runs — the reassurance that leaving is safe. The fuller
/// device management stays in DevicesView; the "All devices" row hands off to it rather than
/// duplicating that surface.
struct SyncPageView: View {
    @EnvironmentObject private var live: LiveState
    @EnvironmentObject private var router: NavRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var motion = NoopMotionState.shared
    private var poseStill: Bool { motion.poseStill(reduceMotion) }

    /// Same 3s debounce as the 7b line (see its doc comment) so the hero ring / serif line don't
    /// strobe between offload chunks.
    @State private var syncing = false
    @State private var hideTask: Task<Void, Never>?

    private var isSyncing: Bool {
        #if DEBUG
        if let pinned = SyncLineDemo.pinned { if case .syncing = pinned { return true } }
        #endif
        return syncing
    }
    private var chunks: Int {
        #if DEBUG
        if case .syncing(let n)? = SyncLineDemo.pinned { return n }
        #endif
        return live.syncChunksThisSession
    }

    var body: some View {
        ScreenScaffold(title: "Sync", subtitle: serifLine,
                       topBackground: liquidFlatInkBackground(),
                       hero: AnyView(hero)) {
            comingAcrossCard
            deviceCard
            if isSyncing {
                ConclusionCard {
                    Text("You can leave this screen. The sync keeps going in the background, and nothing will interrupt you when it finishes.")
                        .font(StrandFont.body)
                        .foregroundStyle(StrandPalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .onAppear { syncing = live.backfilling }
        .onChangeCompat(of: live.backfilling) { raw in
            hideTask?.cancel()
            if raw {
                withAnimation(.easeOut(duration: 0.25)) { syncing = true }
            } else {
                hideTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if !Task.isCancelled { withAnimation(.easeOut(duration: 0.3)) { syncing = false } }
                }
            }
        }
    }

    private var serifLine: LocalizedStringKey {
        if isSyncing { return "Reading the strap" }
        if live.lastSyncedAt != nil { return "Up to date" }
        if live.historySyncExperimental { return "Live heart rate" }
        return "Waiting for the strap"
    }

    /// The 84pt hero ring + the breathing caption. While syncing the ring is INDETERMINATE (a
    /// rotating partial arc) with the honest chunk count inside — never a "4 of 7", because total
    /// pending is unknowable from the protocol. Idle-synced draws the full quiet ring.
    private var hero: some View {
        HStack(alignment: .center, spacing: 20) {
            ZStack {
                if isSyncing {
                    IndeterminateArcRing(size: 84, tint: StrandPalette.chargeBright, still: poseStill)
                    VStack(spacing: 1) {
                        Text(chunks > 0 ? "\(chunks)" : "–")
                            .font(StrandFont.number(22, weight: .light))
                            .foregroundStyle(StrandPalette.onDarkPrimary)
                        Text(chunks == 1 ? "chunk" : "chunks")
                            .font(StrandFont.overlineScaled(9.5)).tracking(1.3).textCase(.uppercase)
                            .foregroundStyle(StrandPalette.onDarkTertiary)
                    }
                } else {
                    HearthProgressRing(fraction: live.lastSyncedAt != nil ? 1 : nil,
                                       lineWidth: 2.5,
                                       trackColor: .white.opacity(0.13),
                                       fillColor: StrandPalette.chargeBright.opacity(0.85),
                                       animated: false)
                        .frame(width: 84, height: 84)
                    Image(systemName: live.lastSyncedAt != nil ? "checkmark" : "ellipsis")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(StrandPalette.onDarkSecondary)
                }
            }
            .frame(width: 84, height: 84)
            .accessibilityHidden(true)

            Text(heroCaption)
                .font(StrandFont.subhead)
                .foregroundStyle(StrandPalette.onDarkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .breathing(still: poseStill || !isSyncing)
        }
        .padding(.top, 6)
    }

    /// Honest caption — no invented time estimate (the mockup's "about forty seconds left" cannot
    /// be computed from the protocol).
    private var heroCaption: String {
        if isSyncing {
            return String(localized: "The strap hands its history over in chunks. This keeps going in the background.")
        }
        if let ts = live.lastSyncedAt {
            return String(localized: "Last full sync \(relativeAgo(ts)).")
        }
        if live.historySyncExperimental {
            return String(localized: "History sync is experimental on this strap. Live heart rate is streaming.")
        }
        return String(localized: "Nothing has synced this session yet.")
    }

    /// ONE honest row — the pipeline reports a chunk count, not a per-category breakdown, so a
    /// single "Strap history" row is everything that can truthfully be said. The rejected-frames
    /// row appears only when raw bytes really were preserved (#77/#91).
    private var comingAcrossCard: some View {
        GroupCard("COMING ACROSS") {
            GroupRow(leading: .icon("arrow.triangle.2.circlepath", StrandPalette.accent),
                     title: "Strap history",
                     subtitle: isSyncing ? "Everything the strap banked since the last sync" : nil,
                     value: strapHistoryValue,
                     valueColor: isSyncing ? StrandPalette.accent : StrandPalette.textSecondary)
            if live.rejectedFramesThisSession > 0 {
                GroupRow(leading: .icon("archivebox", StrandPalette.textTertiary),
                         title: "Unrecognized frames saved",
                         subtitle: "Raw bytes kept on this device for a later decoder",
                         value: "\(live.rejectedFramesThisSession)",
                         valueColor: StrandPalette.textSecondary)
            }
        }
    }

    private var strapHistoryValue: String {
        if isSyncing {
            return chunks > 0 ? String(localized: "\(chunks) chunks") : String(localized: "Syncing…")
        }
        if let ts = live.lastSyncedAt { return String(localized: "Synced \(relativeAgo(ts))") }
        if live.historySyncExperimental { return String(localized: "Experimental") }
        return "–"
    }

    private var deviceCard: some View {
        GroupCard("DEVICE") {
            GroupRow(title: "Connection",
                     value: connectionValue,
                     valueColor: live.connected ? StrandPalette.accent : StrandPalette.textTertiary)
            if live.connected, let pct = live.batteryPct {
                GroupRow(title: "Strap battery", value: batteryValue(pct))
            }
            if let ts = live.lastSyncedAt {
                GroupRow(title: "Last full sync", value: relativeAgo(ts))
            }
            Button { router.openDevices() } label: {
                GroupRow(title: "All devices", showsChevron: true)
            }
            .buttonStyle(.plain)
        }
    }

    private var connectionValue: String {
        // `connectionStatusLabel` is the single source of truth (#266) — reuse, don't re-derive.
        live.connectionStatusLabel
    }

    private func batteryValue(_ pct: Double) -> String {
        let base = "\(Int(pct.rounded()))%"
        return live.charging == true ? String(localized: "\(base) · Charging") : base
    }
}

/// The 7c hero's indeterminate ring: faint track + a rotating partial arc. Continuous rotation is
/// the honest "in flight, no known total" shape; gated still under reduce-motion.
private struct IndeterminateArcRing: View {
    var size: CGFloat
    var lineWidth: CGFloat = 2.5
    var tint: Color
    var still: Bool
    @State private var spin = false

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.13), lineWidth: lineWidth)
            Circle().trim(from: 0, to: 0.3)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(spin ? 270 : -90))
        }
        .frame(width: size, height: size)
        .onAppear {
            guard !still else { return }
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { spin = true }
        }
    }
}
