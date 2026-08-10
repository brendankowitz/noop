import SwiftUI
import StrandDesign

/// Strain/illness early-warning banner. Observes AppModel in isolation so the ~1 Hz HR stream
/// re-renders only this small view, not the whole screen. Renders nothing when there's no alert.
struct HealthAlertBanner: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        if let alert = model.healthAlert {
            // Hearth "Alert" card: the flat clay surface, no shadow and no tint wash. The clay IS the
            // flag — the previous amber-frosted `NoopCard(tint:)` treatment layered a gradient wash and a
            // card shadow on top of that signal, which the design vocabulary reserves for a plain card.
            AlertCard {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(StrandPalette.statusCritical)
                        .frame(width: 30, height: 30)
                        .background(StrandPalette.statusCritical.opacity(0.18), in: Circle())
                        .accessibilityHidden(true)
                    Text(alert)
                        .font(StrandFont.subhead)
                        .foregroundStyle(StrandPalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - The one-Alert-at-a-time rule
//
// The Hearth design contract states it flatly: "At most one Alert on screen. When the illness banner
// and the stress check-in both qualify, the banner wins and the check-in waits." `AlertCard` itself
// can't enforce that (it has no idea what else is on screen), so the priority lives here, beside the
// winner, as ONE readable predicate rather than a rule re-derived at each call site.
//
// The banner is the top of the order because it is the only one of the three Alerts that reports a
// measured multi-day deviation from the user's own baseline; the stress check-in is a passive
// suggestion and the auto-workout card is a suggestion about something already over. A lower-priority
// Alert is SUPPRESSED for that render pass, never dismissed — the check-in's `pending` nudge and the
// detected-workout candidate both survive, so each reappears once the banner clears.
enum TodayAlertPriority {
    /// True while the illness/strain banner is claiming the screen's single Alert slot.
    @MainActor
    static func bannerIsShowing(_ model: AppModel) -> Bool { model.healthAlert != nil }
}
