# Switchboard

A tiny macOS menu bar app that hosts toggleable background **helpers**. It ships
with two generic helper types:

- **Auto Light on External Display** — forces Light mode while an external
  display is connected, and restores your previous appearance when it
  disconnects. Useful if an external panel flickers under dark content.
- **LaunchAgent helpers** — switch any of your launchd user agents on and off
  from the menu. launchd keeps supervising them (including `KeepAlive`
  restarts); Switchboard is just the switch, so they keep running even if you
  quit the app.

Helper *types* live in the code; *which* helpers exist on your machine is pure
configuration (`helpers.json`), so nothing personal is committed to this repo.

## Requirements

- macOS 14 or later.
- Swift 6 toolchain (Xcode 16+ or the matching Swift toolchain). Building the
  app itself works with **Command Line Tools** alone; see [Testing](#testing)
  for the one caveat.

## Quick start

```sh
make run        # build and launch from source; look for the switch icon in the menu bar
```

Open the menu and flip a helper on. There are no helpers from a launchd agent
until you add them to your config (below); the auto-light helper is always
present but does nothing until you enable it.

## Configuration

Switchboard reads:

```
~/Library/Application Support/com.cosmicspork.switchboard/helpers.json
```

A missing file is fine — you just get the auto-light helper with defaults and no
LaunchAgent helpers. See [`helpers.example.json`](helpers.example.json) for the
shape. Use **Open Config Folder…** in the menu to jump there.

```json
{
  "launchAgents": [
    {
      "id": "example-job",
      "name": "Example Job",
      "label": "com.example.job",
      "plistPath": "~/Library/LaunchAgents/com.example.job.plist"
    }
  ],
  "autoLightDisplay": {
    "match": "any-external",
    "onDisconnect": "restore"
  }
}
```

- **`launchAgents[]`** — one entry per launchd agent you want to toggle. `label`
  is the job's launchd label; `plistPath` is its `.plist` (use `print` /
  `launchctl list` to find the label).
- **`autoLightDisplay.match`** — `"any-external"` (any non-built-in display) or
  an exact display name such as `"DELL U3223QE"`.
- **`autoLightDisplay.onDisconnect`** — `restore` (put back the Light/Dark value
  from before the display was connected), `dark`, `light`, or `none`.

### Example: control a personal dev server

If you already run something via a LaunchAgent, just add a row pointing at it:

```json
{
  "id": "notebook-server",
  "name": "Notebook Server",
  "label": "dev.notebook.server",
  "plistPath": "~/Library/LaunchAgents/dev.notebook.server.plist"
}
```

## Permissions

Switching Light/Dark is done by asking System Events to set the appearance, so
the **first time you enable the auto-light helper** macOS shows an Automation
permission prompt. Allow it. If you deny it, the helper shows the error in the
menu rather than failing silently. To re-trigger the prompt later:

```sh
tccutil reset AppleEvents com.cosmicspork.switchboard
```

## Install (autostart at login)

```sh
make install     # builds a .app, copies it to ~/Applications, installs a LaunchAgent
make uninstall   # stops and removes everything
```

`make install` builds an ad-hoc-signed `Switchboard.app`, installs it to
`~/Applications`, and registers a user LaunchAgent
(`com.cosmicspork.switchboard`, `RunAtLoad` + `KeepAlive`) so the app starts at
login. Enabled helpers are restored on launch. (Appearance toggling is most
reliable from the installed bundle, which has a stable code identity for the
Automation permission; running the bare binary may attribute the prompt to your
terminal.)

## Architecture

A `Helper` protocol (`name`, `isEnabled`, `status`, `start()`, `stop()`) with
two concrete types — `LaunchAgentHelper` and `AutoLightDisplayHelper`. A
`HelperStore` loads config, builds helpers, restores previously-enabled ones,
and applies menu toggles; enabled state is persisted in `UserDefaults`.

External effects sit behind injectable, `Sendable` seams so the logic is
testable without spawning processes or touching real hardware:

- `ProcessRunning` — runs `launchctl` / `osascript`.
- `LaunchctlClient` — pure argv builders + thin execution.
- `AppearanceControlling` — reads/sets Dark mode.
- `DisplayWatching` — reports external-display connectivity and emits change
  events.

The connect/disconnect decision is the pure `AutoLightDisplayHelper.evaluate`.

## Testing

Tests use **XCTest** (`Tests/SwitchboardTests`):

```sh
make test    # = swift test
```

`swift test` requires the XCTest module, which ships with **full Xcode**.
Command Line Tools alone do not include XCTest (or Swift Testing), so `swift
test` will report "no such module 'XCTest'" on a CLT-only machine — install
Xcode (or run tests in CI) to execute them. The app itself builds fine with CLT.

## Limitations

- The app must be running for auto-light to work (the LaunchAgent install keeps
  it alive). LaunchAgent helpers keep running regardless.
- Disconnect "restore" puts back the exact Light/Dark value. macOS scheduled
  **Auto** appearance has no public setter, so a machine in Auto mode is
  restored to a fixed Light/Dark value, not back to Auto.
- The binary is unsigned (ad-hoc). Gatekeeper may prompt on first launch, and
  endpoint-security software may flag a locally built tool that drives
  `launchctl` / `osascript`. Build it yourself and you know what it does — the
  source is here.

## License

MIT — see [LICENSE](LICENSE).
