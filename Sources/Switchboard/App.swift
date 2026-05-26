import AppKit
import SwiftUI

@main
struct SwitchboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // A natively-vertical glyph (rotationEffect on a MenuBarExtra label is
        // not reliably applied in the status bar). Vertical faders read like a
        // switchboard and don't clash with the horizontal Control Center icon.
        MenuBarExtra("Switchboard", systemImage: "slider.vertical.3") {
            MenuContentView(store: delegate.store)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = HelperStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only: no Dock icon, no app menu.
        NSApp.setActivationPolicy(.accessory)
        store.bootstrap()
    }
}
