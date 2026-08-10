import SwiftUI
import StrandDesign

/// Shared Shown / Hidden list used by Today sections, Key Metrics, and Your Cards.
///
/// This is a **reorderable** list (drag-to-reorder within "Shown"), so the outer container stays a
/// plain SwiftUI `List` — that's what gives `.onMove` its native drag handle in edit mode for free.
/// Restyle only strips the system grouped-list chrome (headers, insets, separators, background) and
/// draws each row's INTERIOR with the app's `GroupRow` anatomy (icon tile → title/subtitle → trailing
/// accessory), so it reads as the same divided list-row card as everywhere else even though it's
/// structurally still a `List` (Phase 4, #vivid-shimmying-pancake task 1).
struct EditableLayoutList<Item, Options>: View
where Item: Identifiable & Equatable, Options: View {
    @Binding var draft: EditableLayoutDraft<Item>

    let shownTitle: String
    let hiddenTitle: String
    let title: (Item) -> String
    let subtitle: (Item) -> String?
    let icon: (Item) -> String
    let tint: (Item) -> Color
    let configurationLabel: (Item) -> String?
    let onConfigure: (Item) -> Void
    let onReset: () -> Void
    @ViewBuilder let options: () -> Options

    var body: some View {
        List {
            // Not part of the reorderable ForEach below, so this can be a real GroupCard — the caller
            // (e.g. the Key Metrics page's "Display" toggle/segmented control) supplies whatever it
            // needs; EmptyView() renders nothing.
            options()
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            Section {
                ForEach(draft.visible) { item in
                    EditableLayoutRow(
                        title: title(item),
                        subtitle: subtitle(item),
                        icon: icon(item),
                        tint: tint(item),
                        configurationLabel: configurationLabel(item),
                        isVisible: true,
                        canHide: draft.visible.count > 1,
                        onConfigure: { onConfigure(item) },
                        onVisibilityChange: { hide(item) }
                    )
                    .listRowInsets(rowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onMove(perform: moveVisible)
            } header: {
                Text(shownTitle)
                    .strandOverline()
            } footer: {
                Text("Drag to reorder. Move an item to Hidden to remove it from Today without deleting it.")
                    .font(StrandFont.footnote)
                    .foregroundStyle(StrandPalette.textTertiary)
            }

            Section {
                if draft.hidden.isEmpty {
                    Text("Nothing hidden")
                        .foregroundStyle(StrandPalette.textTertiary)
                        .listRowInsets(rowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(draft.hidden) { item in
                        EditableLayoutRow(
                            title: title(item),
                            subtitle: subtitle(item),
                            icon: icon(item),
                            tint: tint(item),
                            configurationLabel: configurationLabel(item),
                            isVisible: false,
                            canHide: true,
                            onConfigure: { onConfigure(item) },
                            onVisibilityChange: { show(item) }
                        )
                        .listRowInsets(rowInsets)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                }
            } header: {
                Text(hiddenTitle)
                    .strandOverline()
            } footer: {
                Text("Hidden items remain available here and can be restored at any time.")
                    .font(StrandFont.footnote)
                    .foregroundStyle(StrandPalette.textTertiary)
            }

            Section {
                Button("Reset This Layout", role: .destructive, action: onReset)
                    .font(StrandFont.body)
                    .foregroundStyle(StrandPalette.statusCritical)
                    .accessibilityLabel("Reset This Layout")
                    .listRowInsets(rowInsets)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(StrandPalette.surfaceBase)
        #if os(iOS)
        .environment(\.editMode, .constant(.active))
        #endif
    }

    /// Matches `GroupCard`'s own horizontal inset (22pt); `GroupRow` supplies its own vertical rhythm.
    private var rowInsets: EdgeInsets { EdgeInsets(top: 0, leading: 22, bottom: 0, trailing: 22) }

    private func moveVisible(from offsets: IndexSet, to destination: Int) {
        draft.moveVisible(from: offsets, to: destination)
    }

    private func hide(_ item: Item) {
        withAnimation(StrandMotion.interactive) {
            draft.hide(item)
        }
    }

    private func show(_ item: Item) {
        withAnimation(StrandMotion.interactive) {
            draft.show(item)
        }
    }
}

/// One row, drawn with the shared `GroupRow` anatomy (icon tile → title/subtitle → trailing
/// accessory): an optional "Edit" link plus the show/hide toggle button. `GroupRow`'s accessory slot
/// (added for this task) carries both, since a reorderable customization row needs more than a single
/// trailing value/chevron.
private struct EditableLayoutRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    let configurationLabel: String?
    let isVisible: Bool
    let canHide: Bool
    let onConfigure: () -> Void
    let onVisibilityChange: () -> Void

    var body: some View {
        GroupRow(
            leading: .icon(icon, isVisible ? tint : StrandPalette.textTertiary),
            title: LocalizedStringKey(title),
            subtitle: subtitle.map { LocalizedStringKey($0) }
        ) {
            HStack(spacing: NoopMetrics.space2) {
                if let configurationLabel {
                    Button(configurationLabel, action: onConfigure)
                        .buttonStyle(.plain)
                        .font(StrandFont.caption.weight(.semibold))
                        .foregroundStyle(StrandPalette.accent)
                        .accessibilityLabel(String(localized: "Edit \(title)"))
                }

                Button(action: onVisibilityChange) {
                    Image(systemName: isVisible ? "minus.circle.fill" : "plus.circle.fill")
                        .font(StrandFont.title2)
                        .foregroundStyle(isVisible ? StrandPalette.textSecondary : StrandPalette.accent)
                }
                .buttonStyle(.plain)
                .disabled(isVisible && !canHide)
                .accessibilityLabel(visibilityLabel)
            }
        }
        .contentShape(Rectangle())
        .listRowBackground(Color.clear)
    }

    private var visibilityLabel: String {
        isVisible
            ? String(localized: "Hide \(title)")
            : String(localized: "Show \(title)")
    }
}
