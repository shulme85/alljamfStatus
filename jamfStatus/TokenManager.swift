//
//  TokenManager.swift
//  alljamfStatus
//
//  Originally created by leslie on 7/9/25.
//  Multi-server token cache added for alljamfStatus fork.
//

import Foundation
import OSLog

actor TokenManager {
    static let shared = TokenManager()

    // Per-server token cache keyed by base URL
    @MainActor private(set) var tokenCache: [String: TokenInfo] = [:]

    // Backward-compat: points to the most recently written token (used by AppDelegate prefs flow)
    @MainActor private(set) var tokenInfo: TokenInfo?

    // MARK: - Read

    func token(for serverUrl: String) async -> TokenInfo? {
        await MainActor.run { tokenCache[serverUrl] }
    }

    func getToken() async -> TokenInfo? {
        await MainActor.run { tokenInfo }
    }

    // MARK: - Multi-server convenience

    /// Returns a valid bearer token for `server`, refreshing if needed.
    @discardableResult
    func ensureToken(for server: ServerConfig) async -> String? {
        let cached = await token(for: server.url)
        if let cached, !cached.renewToken {
            return cached.token
        }
        let password = Credentials().retrieve(service: server.url.fqdn).last ?? ""
        await setToken(serverUrl: server.url,
                       username: server.username.lowercased(),
                       password: password,
                       useApiClient: server.useApiClient ? 1 : 0)
        return await token(for: server.url)?.token
    }

    // MARK: - Core token fetch

    func setToken(serverUrl: String, username: String, password: String, useApiClient: Int = 0) async {

        let tokenUrlString = useApiClient == 0
            ? "\(serverUrl)/api/v1/auth/token"
            : "\(serverUrl)/api/oauth/token"

        Logger.check.debug("request token from: \(tokenUrlString, privacy: .public)")

        guard let tokenUrl = URL(string: tokenUrlString) else {
            writeToLog.message(stringOfText: ["[TokenManager] Invalid URL: \(tokenUrlString)"])
            let info = TokenInfo(url: serverUrl, token: "", expiresAt: Date(),
                                 authMessage: "Invalid URL: \(tokenUrlString)")
            await storeToken(info)
            return
        }

        var request = URLRequest(url: tokenUrl)
        request.httpMethod = "POST"

        if useApiClient == 0 {
            let base64creds = Data("\(username):\(password)".utf8).base64EncodedString()
            request.setValue("Basic \(base64creds)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else {
            let clientString = "grant_type=client_credentials&client_id=\(username)&client_secret=\(password)"
            request.httpBody = clientString.data(using: .utf8)
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AppInfo.userAgentHeader, forHTTPHeaderField: "User-Agent")

        var authMessage = ""

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                writeToLog.message(stringOfText: ["[TokenManager] Auth failed for \(serverUrl). Status: \(statusCode)"])
                switch statusCode {
                case 401: authMessage = "401: Incorrect credentials"
                case 404: authMessage = "404: Server not found"
                default:  authMessage = "\(statusCode == -1 ? "Unknown error" : "\(statusCode)"): login failed"
                }
                Logger.check.debug("failed to get token: \(authMessage, privacy: .public)")
                let info = TokenInfo(url: serverUrl, token: "", expiresAt: Date(), authMessage: authMessage)
                await storeToken(info)
                return
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .formatted(DateFormatter.customISO8601)
            let tokenResponse = try decoder.decode(TokenResponse.self, from: data)

            let newTokenInfo: TokenInfo
            switch tokenResponse {
            case .tokenData(let d):
                let expiration: Date = (d.expires as Date?) ?? Date.now + 20 * 60
                newTokenInfo = TokenInfo(url: serverUrl, token: d.token,
                                        expiresAt: expiration, authMessage: "success")
            case .accessTokenData(let d):
                newTokenInfo = TokenInfo(url: serverUrl, token: d.accessToken,
                                        expiresAt: Date.now + d.expiresIn, authMessage: "success")
            }

            JamfProServer.accessToken = newTokenInfo.token
            JamfProServer.validToken  = true
            Logger.check.debug("granted new token for \(serverUrl, privacy: .public), expires \(newTokenInfo.expiresAt, privacy: .public)")
            await storeToken(newTokenInfo)

        } catch {
            Logger.check.debug("Token request failed: \(error.localizedDescription, privacy: .public)")
            let info = TokenInfo(url: serverUrl, token: "", expiresAt: Date(),
                                 authMessage: error.localizedDescription)
            await storeToken(info)
        }
    }

    // MARK: - Private helpers

    @MainActor
    private func storeToken(_ info: TokenInfo) {
        tokenCache[info.url] = info
        tokenInfo = info    // keep backward-compat pointer current
    }
}
