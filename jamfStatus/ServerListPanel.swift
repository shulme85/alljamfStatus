//
//  ServerListPanel.swift
//  alljamfStatus
//
//  Programmatic server-list management panel (no XIB required).
//  Shows all configured Jamf Pro servers and lets you add/edit/remove them.
//

import AppKit
import Foundation

final class ServerListPanel: NSObject, NSTableViewDataSource, NSTableViewDelegate {

    static let shared = ServerListPanel()

    private var panel: NSPanel?
    private var tableView: NSTableView!
    private var servers: [ServerConfig] { ServerManager.shared.servers }

    private override init() { super.init() }

    // MARK: - Public

    func show() {
        if panel == nil { buildPanel() }
        tableView.reloadData()
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Panel construction

    private func buildPanel() {
        let width: CGFloat  = 520
        let height: CGFloat = 340
        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                        styleMask: [.titled, .closable, .resizable, .utilityWindow],
                        backing: .buffered, defer: false)
        p.title = "Manage Jamf Pro Servers"
        p.isFloatingPanel = true

        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))

        // --- Table ---
        let scrollView = NSScrollView(frame: NSRect(x: 16, y: 52, width: width - 32, height: height - 80))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate   = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 22

        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = "Name"
        nameCol.width = 140
        tableView.addTableColumn(nameCol)

        let urlCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("url"))
        urlCol.title = "URL"
        urlCol.width = 240
        tableView.addTableColumn(urlCol)

        let userCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("username"))
        userCol.title = "User / Client ID"
        userCol.width = 120
        tableView.addTableColumn(userCol)

        scrollView.documentView = tableView
        container.addSubview(scrollView)

        // --- Buttons ---
        let addBtn    = NSButton(title: "+ Add",   target: self, action: #selector(addServer))
        let editBtn   = NSButton(title: "Edit",    target: self, action: #selector(editServer))
        let removeBtn = NSButton(title: "Remove",  target: self, action: #selector(removeServer))

        addBtn.bezelStyle    = .rounded
        editBtn.bezelStyle   = .rounded
        removeBtn.bezelStyle = .rounded

        addBtn.frame    = NSRect(x: 16,  y: 14, width: 80, height: 26)
        editBtn.frame   = NSRect(x: 104, y: 14, width: 80, height: 26)
        removeBtn.frame = NSRect(x: 192, y: 14, width: 80, height: 26)

        container.addSubview(addBtn)
        container.addSubview(editBtn)
        container.addSubview(removeBtn)

        p.contentView = container
        panel = p
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { servers.count }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < servers.count else { return nil }
        let s = servers[row]
        switch tableColumn?.identifier.rawValue {
        case "name":     return s.name
        case "url":      return s.url
        case "username": return s.username
        default:         return nil
        }
    }

    // MARK: - Actions

    @objc private func addServer() {
        showEditSheet(for: nil)
    }

    @objc private func editServer() {
        let row = tableView.selectedRow
        guard row >= 0, row < servers.count else { return }
        showEditSheet(for: servers[row])
    }

    @objc private func removeServer() {
        let row = tableView.selectedRow
        guard row >= 0, row < servers.count else { return }
        let alert = NSAlert()
        alert.messageText     = "Remove \"\(servers[row].name)\"?"
        alert.informativeText = "This removes the server from the monitor list. Keychain credentials are not deleted."
        alert.alertStyle      = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        ServerManager.shared.remove(at: row)
        tableView.reloadData()
    }

    // MARK: - Edit sheet

    private func showEditSheet(for existing: ServerConfig?) {
        let alert = NSAlert()
        alert.messageText = existing == nil ? "Add Jamf Pro Server" : "Edit Server"
        alert.addButton(withTitle: existing == nil ? "Add" : "Save")
        alert.addButton(withTitle: "Cancel")

        let formView = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 180))

        func label(_ text: String, y: CGFloat) -> NSTextField {
            let f = NSTextField(labelWithString: text)
            f.frame = NSRect(x: 0, y: y, width: 100, height: 20)
            f.alignment = .right
            return f
        }
        func field(y: CGFloat, secure: Bool = false) -> NSTextField {
            let f: NSTextField = secure ? NSSecureTextField() : NSTextField()
            f.frame = NSRect(x: 108, y: y, width: 252, height: 22)
            return f
        }

        let nameField     = field(y: 148)
        let urlField      = field(y: 112)
        let userField     = field(y: 76)
        let passField     = field(y: 40, secure: true)
        let apiClientChk  = NSButton(checkboxWithTitle: "Use API client (OAuth)", target: nil, action: nil)
        apiClientChk.frame = NSRect(x: 108, y: 8, width: 252, height: 20)

        nameField.placeholderString = "Production"
        urlField.placeholderString  = "https://acme.jamfcloud.com"
        userField.placeholderString  = "username or client ID"
        passField.placeholderString  = "password or client secret"

        if let s = existing {
            nameField.stringValue    = s.name
            urlField.stringValue     = s.url
            userField.stringValue    = s.username
            apiClientChk.state       = s.useApiClient ? .on : .off
            let creds = Credentials().retrieve(service: s.url.fqdn)
            passField.stringValue    = creds.last ?? ""
        }

        for (lbl, y) in [("Name:", 148.0), ("URL:", 112.0), ("Username:", 76.0), ("Password:", 40.0)] {
            formView.addSubview(label(lbl, y: y))
        }
        formView.addSubview(nameField)
        formView.addSubview(urlField)
        formView.addSubview(userField)
        formView.addSubview(passField)
        formView.addSubview(apiClientChk)

        alert.accessoryView = formView
        if alert.runModal() != .alertFirstButtonReturn { return }

        let url      = urlField.stringValue.baseUrl
        let name     = nameField.stringValue.isEmpty ? url.fqdn : nameField.stringValue
        let username = userField.stringValue
        let password = passField.stringValue
        let useApi   = apiClientChk.state == .on

        guard !url.isEmpty, !username.isEmpty, !password.isEmpty else {
            let err = NSAlert()
            err.messageText = "URL, username, and password are required."
            err.runModal()
            return
        }

        // Save password to Keychain
        Credentials().save(service: url.fqdn, account: username, data: password)

        if var s = existing {
            s.name         = name
            s.url          = url
            s.username     = username
            s.useApiClient = useApi
            ServerManager.shared.update(s)
        } else {
            let newConfig = ServerConfig(name: name, url: url, username: username, useApiClient: useApi)
            ServerManager.shared.add(newConfig)
        }

        tableView.reloadData()
    }
}
