# alljamfStatus — CLAUDE.md

Fork of [jamf/jamfStatus](https://github.com/jamf/jamfStatus) extended to monitor multiple Jamf Pro servers simultaneously.

---

## Project overview

macOS menu bar app (Swift + AppKit, Xcode project). Monitors Jamf Cloud status via `status.jamf.com` and polls `GET /api/v1/notifications` from every configured Jamf Pro server on a configurable interval.

Located at: `~/Desktop/devProjects/6-alljamfStatus/`

Current scale: 5 servers in production, planning for 6+.

---

## Build & run

```bash
open jamfStatus.xcodeproj   # Xcode 15+, macOS 13+ SDK
# ⌘R to build and run
```

No package manager, no scripts. Everything is in the Xcode project.

---

## Key architecture additions (fork-specific)

### `ServerConfig` + `ServerManager` (`Globals.swift`)

- `ServerConfig: Codable` — one Jamf Pro server entry: `id`, `name`, `url`, `username`, `useApiClient`
- `ServerManager` — singleton; loads/saves a `[ServerConfig]` JSON array under `UserDefaults` key `jamfServers`
- Auto-migrates the legacy single-server `jamfServerUrl` key on first launch
- Passwords always stored in Keychain (never in UserDefaults)

### Multi-server `TokenManager` (`TokenManager.swift`)

- `tokenCache: [String: TokenInfo]` — per-URL token dictionary (keyed by base URL)
- `ensureToken(for: ServerConfig) async -> String?` — gets or refreshes token for a specific server
- `tokenInfo` property preserved for backward-compat with `AppDelegate` prefs flow

### `UapiCall` (`UapiCall.swift`)

- New: `get(server: ServerConfig, endpoint: String, completion:)` — fetches from any server using its own token
- Old: `get(endpoint: String, completion:)` — legacy method kept for backward compat

### `StatusMenuController.monitor()` (`StatusMenuController.swift`)

- Calls `ServerManager.shared.load()` each cycle to pick up newly-added servers
- Fetches notifications from all servers concurrently via `DispatchGroup`
- Builds hierarchical `Notifications → Server Name (n) → Alert` submenu
- Health status window still shows the **primary** (first) server only
- Menu bar icon still reflects **Jamf Cloud infrastructure status** (global, not per-server)

### `ServerListPanel` (`ServerListPanel.swift`)

- Programmatic `NSPanel` — no XIB/storyboard required
- Table of all servers (Name, URL, Username)
- Add / Edit / Remove buttons with an NSAlert-based edit sheet
- Writes to `ServerManager` and Keychain on save
- Triggered by `AppDelegate.manageServers_Action(_:)` — wire to a "Manage Servers…" menu item in Interface Builder

---

## Wiring the "Manage Servers…" menu item (one-time IB step)

1. Open `jamfStatus/Base.lproj/MainMenu.xib`
2. Find the menu connected to `cloudStatusMenu` in `StatusMenuController`
3. Add a new **Menu Item** titled `Manage Servers…`
4. Connect its action to `AppDelegate.manageServers_Action:`

---

## Files changed from upstream

| File | Change |
|---|---|
| `Globals.swift` | Added `ServerConfig`, `ServerManager` |
| `TokenManager.swift` | Rewrote to per-server token dict; kept backward-compat `tokenInfo` |
| `UapiCall.swift` | Added `get(server:endpoint:completion:)`; kept legacy method |
| `StatusMenuController.swift` | `monitor()` now iterates all servers; `healthStatus()` uses primary server |
| `AppDelegate.swift` | `saveCreds` syncs `ServerManager`; added `manageServers_Action` |
| `ServerListPanel.swift` | **New file** — programmatic server management panel |
| `README.md` | Replaced with fork-specific docs |
| `CHANGELOG.md` | Added v2.6.0 entry |

---

## UserDefaults keys

| Key | Type | Purpose |
|---|---|---|
| `jamfServers` | JSON Data | `[ServerConfig]` array — the full server list |
| `jamfServerUrl` | String | Legacy upstream key; still read for migration |
| `pollingInterval` | Int | Seconds between polls (min 60, default 300) |
| `useApiClient` | Int | 0 = basic auth, 1 = OAuth (applies to primary server in prefs UI) |
| `menuIconStyle` | String | `"color"` or `"slash"` |
| `hideUntilStatusChange` | Bool | Alert window preference |
| `hideMenubarIcon` | Bool | Minimize icon |
| `launchAgent` | Bool | Start at login |
| `baseUrl` | String | Jamf Cloud status page base URL |

---

## Upstream sync notes

- This fork tracks `jamf/jamfStatus` on the `main` branch
- The multi-server additions are purely additive — no upstream API calls, models, or XIB files were removed
- The `JamfProServer` struct and `Preferences` struct are preserved unchanged for IB outlet compatibility
- When rebasing onto upstream, the main conflict areas are `StatusMenuController.monitor()` and `TokenManager.setToken`
