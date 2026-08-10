import SwiftUI
import StrandDesign
import StrandAnalytics

// MARK: - Auto-detected workout prompt (Today screen)
//
// A single, dismissible Today card that appears ONLY when the opt-in "Auto-detect workouts"
// toggle is on and `Repository.autoDetectCandidate()` finds a recent sustained-elevated HR
// window that isn't already saved and wasn't previously dismissed.
//
// It only ever SUGGESTS: tapping Save creates a manual-style "Workout" for the window (via the
// same manual-save path the edit sheet uses); the X dismisses it durably so it never re-prompts.
// Nothing is created automatically. Design-Reset compliant — a flat NoopCard using NoopMetrics /
// StrandPalette / StrandFont, no gold, matching the other Today cards.

struct AutoWorkoutCard: View {

    @EnvironmentObject var repo: Repository
    /// Observed for ONE thing: whether the illness/strain banner is currently claiming Today's single
    /// Alert slot (see `TodayAlertPriority`). Kept here, in this small leaf, rather than passed down
    /// from `TodayView` — the host deliberately does not observe `AppModel`, because a connected strap
    /// republishes it ~1 Hz and that would re-render the whole dashboard mid-scroll. `HealthAlertBanner`
    /// is its own leaf for exactly the same reason.
    @EnvironmentObject var model: AppModel

    /// Whether the toggle is on. Read here too so the card disappears the instant it's switched off.
    @AppStorage(PuffinExperiment.autoDetectWorkoutsKey) private var autoDetectEnabled = false

    /// The current suggestion, loaded in `.task`. nil → nothing to show.
    @State private var candidate: DetectedWorkout?
    /// Hide immediately on Save/X without waiting for the next reload (avoids a flash of the old card).
    @State private var handledThisSession = false
    /// Guards the Save button while the write is in flight.
    @State private var saving = false

    var body: some View {
        Group {
            // One Alert at a time: the illness/strain banner outranks this suggestion, so while it is up
            // the card waits. Only the RENDER is suppressed — `candidate` is still loaded and the
            // durable dismissal list is untouched, so the suggestion returns intact once the banner
            // clears rather than being silently consumed.
            if !TodayAlertPriority.bannerIsShowing(model),
               autoDetectEnabled, !handledThisSession, let w = candidate {
                card(for: w)
            }
        }
        // Re-scan whenever the data refreshes (a sync bumps refreshSeq) or the toggle flips on.
        .task(id: AutoWorkoutLoadKey(seq: repo.refreshSeq, enabled: autoDetectEnabled)) {
            await reload()
        }
    }

    @ViewBuilder
    private func card(for w: DetectedWorkout) -> some View {
        // Hearth "Alert" card: flat clay, no shadow. This is a SUGGESTION, not a conclusion — the
        // mockup keeps it in the flagged family (with the dismiss ✕ top-right) rather than promoting it
        // to a sage "Insight"/conclusion card, which is reserved for something the app actually decided.
        AlertCard {
            VStack(alignment: .leading, spacing: NoopMetrics.space3) {
                HStack(spacing: NoopMetrics.space2) {
                    Text("Looks like a workout").strandOverline()
                    Spacer()
                    Button {
                        dismiss(w)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(StrandPalette.textTertiary)
                            // 44pt hit target (Apple's floor) around a 13pt glyph — the ✕ sits in the
                            // card's top-right corner where a small hit box is easy to miss.
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss this workout suggestion")
                }

                Text(promptText(w))
                    .font(StrandFont.subhead)
                    .foregroundStyle(StrandPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: NoopMetrics.rowSpacing) {
                    NoopButton("Save it", systemImage: "checkmark", kind: .primary) { save(w) }
                        .disabled(saving)
                    NoopButton("Not a workout", kind: .secondary) { dismiss(w) }
                        .disabled(saving)
                    Spacer(minLength: 0)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// "Looks like a workout [yesterday ]around 14:05–14:32 (avg HR 148, 27 min). Save it?"
    /// Three whole-phrase variants (today / yesterday / dated, #719) so translators see complete
    /// sentences rather than a stitched day-label fragment.
    private func promptText(_ w: DetectedWorkout) -> String {
        let startDate = Date(timeIntervalSince1970: TimeInterval(w.startSec))
        let start = Self.timeFmt.string(from: startDate)
        let end = Self.timeFmt.string(from: Date(timeIntervalSince1970: TimeInterval(w.endSec)))
        let cal = Calendar.current
        if cal.isDateInToday(startDate) {
            return String(localized: "Looks like a workout around \(start)-\(end) (avg HR \(w.avgBpm), \(w.durationMin) min). Save it?")
        }
        if cal.isDateInYesterday(startDate) {
            return String(localized: "Looks like a workout yesterday around \(start)-\(end) (avg HR \(w.avgBpm), \(w.durationMin) min). Save it?")
        }
        return String(localized: "Looks like a workout on \(Self.dateFmt.string(from: startDate)) around \(start)-\(end) (avg HR \(w.avgBpm), \(w.durationMin) min). Save it?")
    }

    private func reload() async {
        guard autoDetectEnabled else { candidate = nil; return }
        let next = await repo.autoDetectCandidate()
        // A fresh scan resets the session guard so a NEW window can surface after one is handled.
        if next != candidate { handledThisSession = false }
        candidate = next
    }

    private func save(_ w: DetectedWorkout) {
        saving = true
        handledThisSession = true
        Task {
            _ = await repo.saveDetectedWorkout(w)
            await repo.refresh()   // surfaces the new workout + drops it from re-suggestion
            saving = false
        }
    }

    private func dismiss(_ w: DetectedWorkout) {
        repo.dismissDetectedSuggestion(w)
        handledThisSession = true
        candidate = nil
    }

    /// HH:mm in the user's locale/timezone.
    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLanguage.activeLocale
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    /// Localized medium date ("Jun 23, 2026") for a bout older than yesterday.
    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = AppLanguage.activeLocale
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
}

/// Reload key: a new sync (seq) or a toggle flip re-runs detection.
private struct AutoWorkoutLoadKey: Equatable {
    let seq: Int
    let enabled: Bool
}
