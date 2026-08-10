import SwiftUI

// MARK: - The six-card vocabulary (bknoop fork addition)
//
// The Hearth mockup's own "Handoff" reference sheet states its full card vocabulary as exactly six
// types and nothing else: Moment · Alert · Action · Group · Insight · Glance. Two of those already
// exist under different names/shapes — the Today hero IS the "Moment" card (bespoke, built where it's
// used, not a generic component since nothing else in the app is a full-bleed sky hero) and the
// pre-existing `InsightCard` in Components.swift predates this vocabulary and serves a different,
// broader role (a per-domain COLORED coaching/status card, not the mockup's flat-sage "the app draws
// a conclusion" card) — kept as-is rather than repainted, to avoid re-coloring its many existing
// call sites. This file adds the remaining three that have no shared component today: `GroupCard`
// (the divided list-row card — the workhorse), `AlertCard` (clay, flagged), and `ActionCard` (ink,
// a large tappable row) — plus `ConclusionCard`, the mockup's literal "Insight" card (sage, no
// shadow), named distinctly from `InsightCard` to avoid colliding with that established component.

// MARK: - Group card (the divided list-row card)

/// One row inside a `GroupCard`. Leading slot is either a colored ring-swatch (34pt), a rounded-square
/// icon tile (38pt), a fixed time column (the "Later today" timeline variant), or nothing. Matches the
/// mockup's row anatomy: leading → title/subtitle stack → trailing value → optional chevron, split
/// from the row above by a 1px hairline.
public struct GroupRow<Accessory: View>: View {
    public enum Leading {
        case swatch(Color)
        case icon(String, Color)
        case time(String)
        case none
    }

    let leading: Leading
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let value: String?
    let valueColor: Color
    let showsChevron: Bool
    @ViewBuilder let accessory: () -> Accessory

    public init(leading: Leading = .none, title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil,
                value: String? = nil, valueColor: Color = StrandPalette.textPrimary,
                showsChevron: Bool = false, @ViewBuilder accessory: @escaping () -> Accessory) {
        self.leading = leading; self.title = title; self.subtitle = subtitle
        self.value = value; self.valueColor = valueColor; self.showsChevron = showsChevron
        self.accessory = accessory
    }

    public var body: some View {
        HStack(alignment: leadingAlignment, spacing: 14) {
            leadingView
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(StrandFont.body).foregroundStyle(StrandPalette.textPrimary).lineLimit(1)
                if let subtitle {
                    // The mockup's row subtitle floors at 12.5pt — one notch below the app's usual
                    // `caption` (12) — so it gets an explicit size rather than reusing that role.
                    Text(subtitle).font(.system(size: 12.5)).foregroundStyle(StrandPalette.textTertiary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let value {
                Text(value).font(StrandFont.body.weight(.medium)).foregroundStyle(valueColor).lineLimit(1)
            }
            accessory()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StrandPalette.textTertiary.opacity(0.7))
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Explicit hit-test shape: without this, only the first NavigationLink-wrapped row in a
        // hand-written (non-ForEach) VStack of these actually responded to taps — SwiftUI's default
        // hit-testing for a complex nested HStack/VStack label doesn't reliably extend across the
        // Spacer/padding regions for every sibling. Matches the pre-existing `MoreRow` (RootTabView),
        // which already carried this for the same reason.
        .contentShape(Rectangle())
        // The row itself draws NO divider — `GroupCard` inserts one BETWEEN rows (see its
        // `_VariadicView` layout below). An earlier "every row draws its own bottom hairline, rely on
        // the card's corner clip to trim the last one" approach didn't actually work: the clip only
        // cuts into the CURVED corner region, and a card's straight bottom edge is flush with where
        // that divider sits — so the last row's hairline rendered as a visible extra border sitting
        // just inside the card's real bottom edge, not something the clip ever trimmed.
    }

    private var leadingAlignment: VerticalAlignment { if case .time = leading { return .firstTextBaseline }; return .center }

    @ViewBuilder private var leadingView: some View {
        switch leading {
        case .swatch(let color):
            Circle().strokeBorder(color, lineWidth: 2).frame(width: 34, height: 34)
        case .icon(let symbol, let color):
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.14))
                .frame(width: 38, height: 38)
                .overlay(Image(systemName: symbol).font(.system(size: 15, weight: .medium)).foregroundStyle(color))
        case .time(let text):
            Text(text).font(.system(size: 12.5)).foregroundStyle(StrandPalette.textTertiary)
                .frame(width: 58, alignment: .leading)
        case .none:
            EmptyView()
        }
    }
}

/// The overwhelming majority of `GroupRow` call sites have no trailing accessory (just a value and/or
/// chevron) — this convenience lets them keep writing `GroupRow(title:...)` without specifying the
/// `Accessory` generic. Rows that need one (e.g. an inline `Toggle` or a reorder drag glyph) call the
/// designated initializer above with an explicit `accessory:` builder instead.
public extension GroupRow where Accessory == EmptyView {
    init(leading: Leading = .none, title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil,
         value: String? = nil, valueColor: Color = StrandPalette.textPrimary,
         showsChevron: Bool = false) {
        self.init(leading: leading, title: title, subtitle: subtitle, value: value, valueColor: valueColor,
                   showsChevron: showsChevron, accessory: { EmptyView() })
    }
}

/// The divided list-row card — the mockup's "Group" type, and its own stated workhorse: "kicker then
/// rows split by a hairline. Everything list-shaped goes here." An optional overline kicker, then
/// `GroupRow`s. Uses `NoopMetrics.rowCardRadius` (24, distinct from a plain card's 26).
public struct GroupCard<Rows: View>: View {
    let title: LocalizedStringKey?
    @ViewBuilder let rows: () -> Rows

    public init(_ title: LocalizedStringKey? = nil, @ViewBuilder rows: @escaping () -> Rows) {
        self.title = title; self.rows = rows
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title).strandOverline().padding(.top, 20).padding(.bottom, 14)
            }
            _VariadicView.Tree(GroupCardRowsLayout(), content: rows)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, title == nil ? 4 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FrostedCardSurface(cornerRadius: NoopMetrics.rowCardRadius))
        .clipShape(RoundedRectangle(cornerRadius: NoopMetrics.rowCardRadius, style: .continuous))
    }
}

/// Inserts a hairline divider BETWEEN each `GroupRow` — never before the first, never after the
/// last — by walking `rows()`'s actual children via `_VariadicView`. This is what makes the divided
/// list read as "N rows, N-1 hairlines" instead of relying on a corner clip to hide a trailing one.
private struct GroupCardRowsLayout: _VariadicView_UnaryViewRoot {
    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
        let lastID = children.last?.id
        ForEach(children) { child in
            child
            if child.id != lastID {
                Rectangle().fill(StrandPalette.hairline).frame(height: 1)
            }
        }
    }
}

// MARK: - Alert card (clay, flagged, no shadow)

/// The mockup's clay "Alert" card: a flagged/attention surface, solid tint fill, no shadow. The
/// design contract states "never more than one at a time" — a per-screen editorial discipline this
/// view doesn't (and can't) enforce on its own. An optional trailing dot-count badge.
public struct AlertCard<Content: View>: View {
    var count: Int?
    @ViewBuilder var content: () -> Content

    public init(count: Int? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.count = count; self.content = content
    }

    public var body: some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StrandPalette.criticalMuted, in: RoundedRectangle(cornerRadius: NoopMetrics.cardRadius, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Circle().fill(StrandPalette.statusCritical))
                        .padding(12)
                }
            }
    }
}

// MARK: - Conclusion card (sage, the mockup's literal "Insight" card)

/// The mockup's sage "Insight" card: solid tint fill, no shadow — "the only place the app draws a
/// conclusion." Named `ConclusionCard`, not `InsightCard`, since that name is already the established
/// per-domain COLORED coaching card in `Components.swift` (a different, broader role predating this
/// vocabulary) — this is the narrower, single-hue "here's the takeaway" callout.
public struct ConclusionCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StrandPalette.accentMuted, in: RoundedRectangle(cornerRadius: NoopMetrics.cardRadius, style: .continuous))
    }
}

// MARK: - Action card (ink, a large tappable row)

/// The mockup's ink "Action" card: a dark, full-width tappable row with a circular glyph, a
/// title/subtitle, and a trailing chevron. Reserved for a single deliberate call-to-action per screen
/// (e.g. "Start a live session") — not a generic button substitute.
public struct ActionCard: View {
    let icon: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let action: () -> Void

    public init(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil,
                action: @escaping () -> Void) {
        self.icon = icon; self.title = title; self.subtitle = subtitle; self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 42, height: 42)
                    .overlay(Image(systemName: icon).font(.system(size: 17, weight: .medium)).foregroundStyle(StrandPalette.onDarkPrimary))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(StrandFont.body).foregroundStyle(StrandPalette.onDarkPrimary)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 12.5)).foregroundStyle(StrandPalette.onDarkSecondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(StrandPalette.onDarkTertiary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StrandPalette.textPrimary, in: RoundedRectangle(cornerRadius: NoopMetrics.cardRadius, style: .continuous))
        }
        .buttonStyle(StrandPressableButtonStyle(cornerRadius: NoopMetrics.cardRadius))
    }
}

#if DEBUG && !os(watchOS)
#Preview("Six-card vocabulary") {
    ScrollView {
        VStack(spacing: 12) {
            GroupCard("SLOWER SIGNALS") {
                GroupRow(leading: .swatch(StrandPalette.restColor), title: "Skin temperature", value: "+0.4°", showsChevron: true)
                GroupRow(leading: .swatch(StrandPalette.effortColor), title: "Resting heart rate", value: "57 bpm", showsChevron: true)
                GroupRow(leading: .time("6:40"), title: "Wind-down reminder", subtitle: "In 40 minutes")
            }
            AlertCard(count: 2) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("MINOR SIGNS").strandOverline()
                    Text("A couple of things worth a look today.").font(StrandFont.body)
                }
            }
            ConclusionCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("WHAT IT MEANS").strandOverline()
                    Text("Your body handled last night well — safe to push today.").font(StrandFont.body)
                }
            }
            ActionCard(icon: "waveform.path.ecg", title: "Start a live session", subtitle: "Beta") {}
        }
        .padding(20)
    }
    .background(StrandPalette.surfaceBase)
}
#endif
