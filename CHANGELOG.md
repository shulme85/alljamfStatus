## Change log

2026-05-08: v2.6.0 (alljamfStatus fork) - Multi-server support. Add `ServerConfig` model and `ServerManager` for storing an unlimited list of Jamf Pro servers. Per-server token cache in `TokenManager`. `UapiCall` gains a server-parameterized `get(server:endpoint:completion:)` method. `StatusMenuController.monitor()` polls all servers concurrently and renders a hierarchical Notifications → Server → Alerts submenu. `ServerListPanel` provides a programmatic Add/Edit/Remove panel (no XIB required). Auto-migrates existing single-server config from upstream on first launch.

2025-01-19: v2.5.4 - Better handling of the health status window.

2025-01-15: v2.5.3 - Actively update health status window if it is presented.

2025-12-24: v2.5.1 - Log health status rates below 1.0.

2025-12-21: v2.5.0 - Add basic hardware, OS, and jamfStatus app usage collection. Data is sent anonymously to [TelemetryDeck](https://telemetrydeck.com) to aid in the development of the app. View 'About...' to opt out of sending the data. Add ability to view health-status for Jamf Cloud hosted instances. Fix an issue with token renewal.

2023-12-06: v2.4.1 - Minor updates to the alerts display.

2023-11-11: v2.4.0 - Fix issue with notifications not being displayed.  Add ability to use API client.

2023-04-07: v2.3.6 - Update logging to prevent potential looping.  

2022-10-02: v2.3.2 - Rework authentication/token refresh.

2022-06-12: v2.3.1 - Clean up notificatations not displaying properly.

2021-10-15: v2.3.0 - Updated notifications display.
