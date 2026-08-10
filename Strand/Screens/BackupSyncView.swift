import SwiftUI
import StrandDesign

/// Backup & Sync (folder destination). The Apple mirror of the Android `BackupSyncScreen`: pick a
/// folder, turn on daily auto-backup (an on-launch catch-up), back up now, or restore from a snapshot
/// already in that folder. Snapshots are the existing `.noopbak` whole-DB format. Point the folder at
/// Google Drive / iCloud / Dropbox for off-device sync with no in-app cloud account.
struct BackupSyncView: View {
    @EnvironmentObject var model: AppModel

    @State private var auto = FolderBackup.autoEnabled
    @State private var folderLabel = FolderBackup.folderLabel()
    @State private var lastMs = FolderBackup.lastBackupMs
    @State private var keep = FolderBackup.keepCount
    @State private var busy = false

    // Result alert (backup outcome / restore outcome).
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    // Restore-from-folder flow (must-fix #1 + #2): the folder's snapshots are listed inline (the mockup's
    // "Snapshots" group); choosing one arms a destructive confirmation; only confirming runs the overwrite.
    @State private var snapshots: [FolderBackup.Snapshot] = []
    @State private var pendingRestore: FolderBackup.Snapshot?
    @State private var confirmRestore = false

    var body: some View {
        ScreenScaffold(
            title: "Backup",
            // The header's serif line states the real last-snapshot fact. NOT the mockup's "412 MB":
            // `FolderBackup.Snapshot` carries a name + a timestamp and nothing else, so a size would mean
            // new folder-stat I/O — see the note on `snapshotsCard`.
            subtitle: LocalizedStringKey(headerStatement),
            // Flat ink, not the sky — Backup is an archive/utility page, not a lived moment.
            topBackground: liquidFlatInkBackground()
        ) {
            folderCard
            // The mockup promotes the unencrypted-backup warning from a footnote inside the folder card to
            // its own clay Alert. Deliberate: this is the one thing on the page a user must not miss before
            // pointing the folder at a cloud service (#644).
            unencryptedAlert
            snapshotsCard
            backupNowAction
        }
        // The inline "Snapshots" list reads the folder on appear (and after a folder change / a backup).
        .task { await refreshSnapshots() }
        // Result of a backup or a restore.
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(alertMessage) }
        // Explicit in-app destructive confirmation BEFORE any overwrite (must-fix #2).
        .alert("Restore this backup?", isPresented: $confirmRestore, presenting: pendingRestore) { snap in
            Button("Replace all data", role: .destructive) { runRestore(snap) }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: { snap in
            // A hand-named file with no resolved date (timeMs 0) confirms by NAME, not "1 Jan 1970".
            Text(snap.timeMs > 0
                ? "Replace all current data with the backup from \(absoluteTime(snap.timeMs))? This cannot be undone."
                : "Replace all current data with the backup \(snap.name)? This cannot be undone.")
        }
    }

    // MARK: - Header statement

    /// The real last-snapshot fact for the header band. Deliberately carries no size: `FolderBackup`
    /// records a snapshot's name and time only, so "412 MB" would need new folder-stat I/O in
    /// `BackupSync.swift` — outside this restyle, and not something to guess at.
    private var headerStatement: String {
        guard let folderLabel else {
            return String(localized: "No folder chosen yet. Pick one your cloud app already syncs, or any local folder.")
        }
        guard lastMs > 0 else {
            return String(localized: "No backup yet. Your folder is \(folderLabel), ready when you are.")
        }
        return String(localized: "Last snapshot \(relativeTime(lastMs)), kept in \(folderLabel).")
    }

    // MARK: - Cards

    /// The mockup's "Backup folder" group: where snapshots go, the daily auto-backup switch, and the
    /// retention count. Every control is the SAME binding the old stacked card carried — `chooseFolder()`
    /// still opens the real picker, the toggle still writes `FolderBackup.autoEnabled`, the picker still
    /// writes `FolderBackup.keepCount`.
    private var folderCard: some View {
        GroupCard("Backup folder") {
            Button { chooseFolder() } label: {
                // Row subtitles are ONE line by design (`GroupRow`), so they stay short enough to read
                // whole — the iCloud guidance that used to sit here is now the header's own sentence.
                GroupRow(title: LocalizedStringKey(folderLabel ?? String(localized: "No folder chosen")),
                         subtitle: "Where snapshots are written.",
                         value: folderLabel == nil ? String(localized: "Choose") : String(localized: "Change"),
                         valueColor: StrandPalette.accent)
            }
            .buttonStyle(.plain)
            .disabled(busy)
            .accessibilityLabel(folderLabel == nil ? "Choose backup folder" : "Change backup folder")

            #if os(iOS)
            // #52: some iOS 26 users can't select a folder in the system picker (its "Open" button
            // never fires). This backs up inside NOOP's own Files-visible folder instead — no picker.
            if !FolderBackup.useInternalFolder {
                Button { useNoopFolder() } label: {
                    GroupRow(title: "Use NOOP's own folder",
                             subtitle: "Browse them in Files.",
                             value: String(localized: "Use"),
                             valueColor: StrandPalette.accent)
                }
                .buttonStyle(.plain)
                .disabled(busy)
            }
            #endif

            GroupRow(title: "Daily auto-backup",
                     subtitle: "Runs when you next open NOOP.") {
                Toggle("Daily auto-backup", isOn: $auto)
                    .labelsHidden().toggleStyle(.switch).tint(StrandPalette.accent)
                    .disabled(folderLabel == nil)
                    .onChangeCompat(of: auto) { on in FolderBackup.autoEnabled = on }
            }

            // Retention: how many dated snapshots to keep. Wired to FolderBackup.keepCount; the next
            // backup prunes the oldest beyond this count (BackupSync.snapshotsToPrune, unchanged).
            GroupRow(title: "Keep last snapshots",
                     subtitle: "Older ones are pruned, oldest first.") {
                Picker("Keep last snapshots", selection: $keep) {
                    ForEach(FolderBackup.keepOptions, id: \.self) { n in Text("\(n)").tag(n) }
                }
                .labelsHidden().pickerStyle(.menu).tint(StrandPalette.accent)
                .onChangeCompat(of: keep) { n in FolderBackup.keepCount = n }
            }
        }
    }

    /// #644, promoted to the clay Alert card: these `.noopbak` snapshots are a plain, unencrypted ZIP —
    /// pointing this folder at a cloud sync app also uploads that readable file there. Same words as the
    /// footnote it replaces; the card is what makes it unmissable.
    private var unencryptedAlert: some View {
        AlertCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(StrandPalette.statusCritical)
                    .accessibilityHidden(true)
                Text("These backups are unencrypted. If this folder syncs to Drive, Dropbox or iCloud, the readable file goes there as well — only point it at a service you trust.")
                    .font(StrandFont.body)
                    .foregroundStyle(StrandPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The mockup's "Snapshots" group — the folder's own backups, newest first, listed inline instead of
    /// behind a picker sheet. Tapping one still arms the SAME destructive confirmation before any
    /// overwrite (must-fix #2); nothing restores without it. No size column: `FolderBackup.Snapshot` has
    /// no size (see `headerStatement`), and a made-up "MB" is exactly the kind of number this app doesn't
    /// print. A hand-named file whose date lookup failed shows its name, never "1 Jan 1970" (#852).
    private var snapshotsCard: some View {
        GroupCard("Snapshots") {
            if folderLabel == nil {
                GroupRow(title: "Nothing yet",
                         subtitle: "Choose a folder above, then back up.",
                         valueColor: StrandPalette.textTertiary)
            } else if snapshots.isEmpty {
                GroupRow(title: "No backups in this folder yet",
                         subtitle: "Back up now to make the first one.",
                         valueColor: StrandPalette.textTertiary)
            } else {
                ForEach(snapshots) { snap in
                    Button {
                        pendingRestore = snap
                        confirmRestore = true
                    } label: {
                        GroupRow(title: LocalizedStringKey(primaryLabel(snap)),
                                 subtitle: snap.timeMs > 0 ? LocalizedStringKey(snap.name) : nil,
                                 showsChevron: true)
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                    .accessibilityLabel(restoreAccessibilityLabel(snap))
                }
            }
        }
    }

    /// The mockup's ink "Back up now" row — the same `FolderBackup.backupNow(checkpoint:)` the old primary
    /// button ran, with the same folder/busy gate.
    private var backupNowAction: some View {
        ActionCard(icon: "icloud.and.arrow.up",
                   title: busy ? "Working…" : "Back up now",
                   subtitle: LocalizedStringKey(lastMs > 0
                        ? String(localized: "Last backup \(relativeTime(lastMs)).")
                        : String(localized: "Writes a full snapshot to your folder."))) {
            backupNow()
        }
        .disabled(folderLabel == nil || busy)
        // `.disabled` alone leaves a custom-filled card looking tappable, so dim it too — a dark ink
        // row that can't run should read as unavailable, not just fail silently on tap.
        .opacity(folderLabel == nil || busy ? 0.5 : 1)
        .accessibilityLabel("Back up now")
    }

    /// A snapshot row's headline: a friendly date when one resolved, else the filename (never the epoch).
    private func primaryLabel(_ snap: FolderBackup.Snapshot) -> String {
        snap.timeMs > 0 ? absoluteTime(snap.timeMs) : snap.name
    }

    private func restoreAccessibilityLabel(_ snap: FolderBackup.Snapshot) -> String {
        snap.timeMs > 0 ? String(localized: "Restore backup from \(absoluteTime(snap.timeMs))")
                        : String(localized: "Restore backup \(snap.name)")
    }

    /// Re-read the folder's snapshots for the inline list. Off the main actor (a folder listing is file
    /// I/O), mirroring how `runRestore` detaches its own work.
    private func refreshSnapshots() async {
        let list = await Task.detached(priority: .utility) { FolderBackup.listSnapshots() }.value
        snapshots = list
    }

    // MARK: - Actions

    private func chooseFolder() {
        #if os(macOS)
        if FolderBackup.pickFolder() != nil {
            folderLabel = FolderBackup.folderLabel()
            Task { await refreshSnapshots() }
        }
        #else
        // #1000a: on iOS the folder picker has reportedly refused to enable its Select button, leaving
        // the user with only Cancel and NOOP silently doing nothing. We can't tell a deliberate Cancel
        // apart from that dead-button dead-end (both come back nil), so when no folder arrives we show
        // the screen's normal result alert with a concrete workaround instead of staying silent. Mildly
        // chatty on a genuine Cancel; honest and actionable when the picker is actually broken.
        // `busy` guards against a double-tap stacking a second picker presentation on top of the first.
        busy = true
        Task {
            let picked = await FolderBackup.pickFolder()
            busy = false
            if picked != nil {
                folderLabel = FolderBackup.folderLabel()
                await refreshSnapshots()
            } else if !FolderBackup.useInternalFolder {
                // Only nag when there's no working destination. If the internal fallback is already
                // active, a cancelled picker changed nothing — and the button the message points at is
                // hidden, so alerting here would send the user chasing a control that isn't shown.
                alertTitle = String(localized: "No folder selected")
                alertMessage = String(localized: "NOOP didn't get a folder back from the picker. If the Open button won't do anything, tap \"Use NOOP's own folder\" below to back up inside NOOP instead — you can read those backups from the Files app.")
                showAlert = true
            }
        }
        #endif
    }

    #if os(iOS)
    // #52: picker-free fallback. Back up inside NOOP's own Files-visible folder (On My iPhone → NOOP →
    // Backups). No folder picker, no security-scoped bookmark — works even where the picker won't select.
    private func useNoopFolder() {
        FolderBackup.useNoopFolder()
        folderLabel = FolderBackup.folderLabel()
        Task { await refreshSnapshots() }
        alertTitle = String(localized: "Using NOOP's folder")
        alertMessage = String(localized: "Backups will be saved inside NOOP. Open the Files app → On My iPhone → NOOP → Backups to see them, or drag that folder into iCloud Drive to read it on your Mac. To use a different folder later, tap Change folder.")
        showAlert = true
    }
    #endif

    private func backupNow() {
        busy = true
        Task {
            let ok = await FolderBackup.backupNow(checkpoint: { await model.repo.checkpointForBackup() })
            await MainActor.run {
                lastMs = FolderBackup.lastBackupMs
                busy = false
                alertTitle = ok ? String(localized: "Backed up") : String(localized: "Backup problem")
                alertMessage = ok
                    ? String(localized: "Saved a backup to your folder.")
                    : String(localized: "Backup failed - re-pick the folder and try again.")
                showAlert = true
            }
            // The new snapshot (and any pruned by retention) change the inline list.
            await refreshSnapshots()
        }
    }

    private func runRestore(_ snap: FolderBackup.Snapshot) {
        pendingRestore = nil
        busy = true
        Task {
            // The restore is synchronous file I/O; run it off the main actor so the UI stays responsive
            // for a large store, then report on the main actor.
            let result = await Task.detached(priority: .userInitiated) {
                FolderBackup.restore(snapshotNamed: snap.name)
            }.value
            await MainActor.run {
                busy = false
                switch result {
                case .imported:
                    alertTitle = String(localized: "Restored")
                    alertMessage = String(localized: "Fully quit and reopen NOOP to load it.")
                case .failure(let m):
                    alertTitle = String(localized: "Restore problem"); alertMessage = m
                case .cancelled, .exported:
                    alertTitle = String(localized: "Restore problem"); alertMessage = String(localized: "Couldn't restore that backup.")
                }
                showAlert = true
            }
        }
    }

    // MARK: - Formatting

    private func relativeTime(_ ms: Int) -> String {
        let f = RelativeDateTimeFormatter()
        return f.localizedString(for: Date(timeIntervalSince1970: Double(ms) / 1000.0), relativeTo: Date())
    }

    private func absoluteTime(_ ms: Int) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: Date(timeIntervalSince1970: Double(ms) / 1000.0))
    }
}
