import SwiftUI
import StrandDesign
import StrandAnalytics

// MARK: - Illness ladder (bknoop fork, mockup 5a)
//
// A dedicated detail screen for `IllnessSignalEngine.Result`, today only surfaced as a card
// (`HeadsUpCard` in SkinTempCardsView.swift). This adds the mockup's 3-rung Quiet/Minor/Major
// ladder as a header, then EMBEDS `HeadsUpCard` unchanged for the signal-by-signal breakdown —
// the existing card already renders that correctly and there is no reason to duplicate it.
//
// The mockup's ladder is driven by a raw 6-signal count (0-1/2-3/4+); the real engine tracks 4
// signals and outputs a qualitative `Level`, not a raw count with those exact breakpoints, so this
// maps the real 5-case `Level` onto the 3 rungs rather than inventing a count the engine doesn't
// produce: quiet -> Quiet; mild/suppressed -> Minor; raised/alreadyUnwell -> Major.
struct IllnessLadderView: View {
    let result: IllnessSignalEngine.Result
    var distance: IllnessDistance.Result? = nil

    private enum Rung: Int, CaseIterable {
        case quiet, minor, major

        var label: String {
            switch self {
            case .quiet: return String(localized: "Quiet")
            case .minor: return String(localized: "Minor")
            case .major: return String(localized: "Major")
            }
        }
        var signCount: String {
            switch self {
            case .quiet: return String(localized: "0–1 signs")
            case .minor: return String(localized: "2–3 signs")
            case .major: return String(localized: "4+ signs")
            }
        }
    }

    private var currentRung: Rung {
        switch result.level {
        case .quiet:                  return .quiet
        case .mild, .suppressed:      return .minor
        case .raised, .alreadyUnwell: return .major
        }
    }

    var body: some View {
        ScreenScaffold(title: "Signals", subtitle: "Six signals, one ladder") {
            VStack(alignment: .leading, spacing: NoopMetrics.sectionGap) {
                ladder
                HeadsUpCard(result: result, distance: distance)
                Text(IllnessSignalEngine.disclaimerTail)
                    .font(StrandFont.footnote)
                    .foregroundStyle(StrandPalette.textTertiary)
            }
            .padding(.horizontal, NoopMetrics.screenPadding)
        }
    }

    private var ladder: some View {
        NoopCard(padding: 4) {
            VStack(spacing: 0) {
                ForEach(Rung.allCases, id: \.self) { rung in
                    rungRow(rung)
                    if rung != .major {
                        Divider().overlay(StrandPalette.hairline)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func rungRow(_ rung: Rung) -> some View {
        let isCurrent = rung == currentRung
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(isCurrent ? flagColor(for: rung) : StrandPalette.hairlineStrong)
                .frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(rung.label)
                    .font(StrandFont.body)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .foregroundStyle(isCurrent ? StrandPalette.textPrimary : StrandPalette.textSecondary)
                Text(rung.signCount)
                    .font(StrandFont.caption)
                    .foregroundStyle(StrandPalette.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func flagColor(for rung: Rung) -> Color {
        switch rung {
        case .quiet: return StrandPalette.textPrimary
        case .minor: return StrandPalette.statusWarning
        case .major: return StrandPalette.statusCritical
        }
    }
}

#if DEBUG
#Preview("IllnessLadderView — minor") {
    NavigationStack {
        IllnessLadderView(result: IllnessSignalEngine.Result(
            score: 42, level: .mild,
            firedSignals: ["RHR +4", "Respiration +0.6 rpm"],
            suppressedBy: [], signalCount: 2,
            copy: "A couple of signals are up. Nothing that needs action yet."))
    }
}

#Preview("IllnessLadderView — major") {
    NavigationStack {
        IllnessLadderView(
            result: IllnessSignalEngine.Result(
                score: 78, level: .raised,
                firedSignals: ["RHR +9", "HRV −28%", "Skin temp +0.9°C", "Respiration +1.1 rpm"],
                suppressedBy: [], signalCount: 4,
                copy: "Several signals are up together. Worth taking it easy today."),
            distance: IllnessDistance.Result(distance: 3.8, deviatingFeatures: 4, fires: true, usedDiagonalFallback: false))
    }
}
#endif
