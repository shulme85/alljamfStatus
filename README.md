# alljamfStatus

> **Fork of [jamf/jamfStatus](https://github.com/jamf/jamfStatus)** — extended to monitor multiple Jamf Pro servers simultaneously from a single menu bar app.

<img src="./jamfStatus/images/menubar.png" alt="menu bar" width="200" />

---

## What's different in this fork

| Feature | jamf/jamfStatus (upstream) | alljamfStatus (this fork) |
|---|---|---|
| Jamf Pro servers monitored | 1 | Unlimited (5–6 in production, more planned) |
| Notification menu | Flat list from one server | Hierarchical: **Server Name → Alerts** |
| Token management | Single token | Per-server token cache (basic auth or OAuth) |
| Server storage | Single `jamfServerUrl` in UserDefaults | JSON array (`jamfServers`) — auto-migrates from upstream |
| Server management UI | Single prefs pane | Single prefs pane (primary) + **Manage Servers…** panel |
| Health status window | Primary server | Primary server (first in list) |
| Jamf Cloud status icon | ✓ | ✓ unchanged |

---

## How it works

### Polling loop

On each polling cycle the app:

1. Reads the full server list from `ServerManager`
2. Fetches `GET /api/v1/notifications` from **every** configured server concurrently
3. Builds a hierarchical **Notifications (N total) → Server Name (n) → Alerts** submenu
4. Checks `status.jamf.com` for global Jamf Cloud infrastructure status (drives the menu bar icon color)
5. Fetches health-status metrics from the **primary server** (first in list) for the Health Status window

### Menu structure

```
☁  (menu bar icon — green / yellow / red = Jamf Cloud status)
│
├── Notifications (7)
│   ├── Production (3)              ← server label (not clickable)
│   │     VPP token expiring in 30 days
│   │     Push cert expiring in 14 days
│   │     Device count exceeded
│   ├── ─────────────────────────
│   ├── Staging (2)
│   │     Certificate expiring in 7 days
│   │     LDAP connection failed
│   └── ─────────────────────────
│
├── Health Status
├── View Jamf Cloud Status
├── Manage Servers…                 ← new in this fork
├── Preferences…
├── Show Logs
└── Quit
```

### Menu bar icon

The icon color reflects **Jamf Cloud infrastructure status** (green / yellow / red), identical to upstream. Per-server Jamf Pro issues appear in the Notifications submenu, not on the icon.

---

## Managing servers

### Option A — Manage Servers… panel (recommended)

Wire `manageServers_Action:` to a **"Manage Servers…"** menu item in `Base.lproj/MainMenu.xib` (see setup below). The panel lets you:

- **Add** a server (name, URL, username or client ID, password or secret, OAuth toggle)
- **Edit** an existing server
- **Remove** a server

Passwords are stored in the macOS Keychain (one entry per FQDN), never in UserDefaults.

### Option B — Preferences window (primary server)

The existing Preferences window edits the **first** server in the list — identical UX to upstream. Any URL saved there is automatically upserted into the server list.

### Option C — UserDefaults JSON (scripting / bulk setup)

The server list is stored as a JSON array under the `jamfServers` key:

```bash
# View current list
defaults read com.jamf.jamfstatus jamfServers | python3 -m json.tool

# Seed the list (replace values; passwords go in Keychain separately)
python3 - <<'EOF'
import json, subprocess, uuid

servers = [
    {"id": str(uuid.uuid4()), "name": "Production",  "url": "https://prod.jamfcloud.com",     "username": "monitor", "useApiClient": False},
    {"id": str(uuid.uuid4()), "name": "Staging",     "url": "https://staging.jamfcloud.com",  "username": "monitor", "useApiClient": False},
    {"id": str(uuid.uuid4()), "name": "Dev",         "url": "https://dev.jamfcloud.com",      "username": "monitor", "useApiClient": False},
    {"id": str(uuid.uuid4()), "name": "EU Prod",     "url": "https://eu-prod.jamfcloud.com",  "username": "monitor", "useApiClient": True},
    {"id": str(uuid.uuid4()), "name": "EU Staging",  "url": "https://eu-stg.jamfcloud.com",   "username": "monitor", "useApiClient": True},
]
data = json.dumps(servers)
subprocess.run(["defaults", "write", "com.jamf.jamfstatus", "jamfServers", data])
print("Written. Restart alljamfStatus to pick up changes.")
EOF
```

Passwords must be added separately via the Manage Servers… panel or the Keychain.

### Migration from upstream jamfStatus

If you already have a single server configured in upstream `jamfStatus`, `alljamfStatus` **automatically migrates** it on first launch. No action needed.

---

## Setup

### Requirements

- macOS 13+
- Xcode 15+
- Read-only Jamf Pro API account on each server  
  *(no permissions = cloud-level notifications only; read-only on all objects = full notification set)*

### Build

```bash
git clone https://github.com/shulme85/alljamfStatus.git
cd alljamfStatus
open jamfStatus.xcodeproj
# Build & Run in Xcode (⌘R)
```

### One-time Interface Builder step — add "Manage Servers…"

1. Open `jamfStatus/Base.lproj/MainMenu.xib` in Xcode
2. Find the status-bar menu (the one connected to `cloudStatusMenu` in `StatusMenuController`)
3. Drag a new **Menu Item** into the menu — set its title to `Manage Servers…`
4. Control-drag from the menu item to **AppDelegate** → connect to `manageServers_Action:`
5. Build and run

---

## Preferences

Access via menu bar icon → **Preferences…**

| Setting | Description |
|---|---|
| Polling interval | How often to check all servers (minimum 60 s, default 300 s) |
| Alert window | Show on every poll vs. only when status changes |
| Menu bar icon | Minimize / full; Color vs. slash style |
| Launch agent | Start at login |
| Server URL / credentials | Edits the primary (first) server |

For the full server list, use **Manage Servers…**

---

## Health Status window

Shows request-success rates for the **primary server** (first in the list):

- API, UI, Enrollment, Device, Default — at 30 s, 1 m, 5 m, 15 m, 30 m windows

> Per-server health status in a single window is on the roadmap.

<img src="./jamfStatus/images/healthStatus.png" alt="Health Status" width="600" />

---

## Logging

```
~/Library/Logs/jamfStatus/jamfStatus.log
```

Rotated at 5 MB; up to 10 archives retained. Per-server auth failures and notification fetches are tagged with the server name.

```
Fri May 08 10:30:00 [ServerManager] 5 server(s) configured
Fri May 08 10:30:00 checking notifications: Production (https://prod.jamfcloud.com)
Fri May 08 10:30:01 checking notifications: Staging (https://staging.jamfcloud.com)
...
Fri May 08 10:30:03 Jamf Cloud: All systems go.
```

Stream debug logs:

```bash
log stream --debug --predicate 'subsystem == "com.jamf.jamfstatus"'
```

---

## Alert types monitored

All upstream notification types are supported. Each alert is attributed to its source server in the submenu and in the log file.

<details>
<summary>Full notification list (same as upstream)</summary>

- Certificate expired / expiring — Tomcat SSL, SSO, GSX, Push, Cloud LDAP, Push Proxy
- Invalid script / EA / policy references to `/usr/sbin/jamf`
- Management account payload security (single and multiple policies)
- VPP / Volume Purchasing token expired or expiring
- DEP / Automated Device Enrollment instance expired or expiring
- Frequent inventory collection policy
- Patch update available / EA requiring attention
- Apple T&C not signed (DEP, Apple School Manager)
- App no longer device-assignable
- Healthcare Listener configuration errors
- SSL certificate verification disabled
- Jamf Infrastructure Manager not checking in
- Device count exceeded
- Microsoft Intune integration issues (inventory, heartbeat, auth)
- Third-party signing certificate expired / expiring
- LDAP server configuration error / proxy connection status
- Managed Apple ID mismatches / duplicates
- Built-in CA expiring / expired / renewal success or failure
- APNs certificate revoked / connection failure
- Jamf Protect update available
- Jamf Connect update available (minor and major)
- Device Compliance connection interrupted
- Conditional Access connection interrupted
- Duplicate user email addresses

</details>

---

## Credits

- Original app: [jamf/jamfStatus](https://github.com/jamf/jamfStatus) by Leslie Helou / Jamf Professional Services
- Multi-server fork: [@shulme85](https://github.com/shulme85)

## License

MIT — see [LICENSE](./LICENSE)
