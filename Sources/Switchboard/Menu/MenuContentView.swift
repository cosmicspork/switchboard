import SwiftUI

/// The dropdown shown from the menu bar icon: one toggle per helper, plus
/// status/errors and a couple of utility actions.
struct MenuContentView: View {
    let store: HelperStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Switchboard")
                .font(.headline)

            if let loadError = store.loadError {
                Label(loadError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if store.helpers.isEmpty {
                Text("No helpers configured.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.helpers, id: \.id) { helper in
                    HelperRow(helper: helper, store: store)
                }
            }

            Divider()

            Button("Reload Config", action: store.reloadConfig)
            Button("Open Config Folder…", action: openConfigFolder)
            Button("Quit Switchboard") { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 300)
    }

    private func openConfigFolder() {
        let directory = ConfigLoader.defaultURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }
}

/// A single helper's toggle and status line. Reading `helper.isEnabled` and
/// `helper.status` here lets SwiftUI's Observation track the @Observable helper.
private struct HelperRow: View {
    let helper: any Helper
    let store: HelperStore

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(helper.name, isOn: Binding(
                get: { helper.isEnabled },
                set: { store.setEnabled($0, for: helper) }
            ))
            if let error = helper.status.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
