//
//  UapiCall.swift
//  jamfStatus
//
//  Created by Leslie Helou on 9/1/19.
//  Copyright © 2019 Leslie Helou. All rights reserved.
//

// get notifications from https://jamf.pro.server/uapi/notifications/alerts - old
// get notifications from https://jamf.pro.server/api/v1/notifications


import Foundation
import OSLog

class UapiCall: NSObject, URLSessionDelegate, URLSessionDataDelegate, URLSessionTaskDelegate {

    var theUapiQ = OperationQueue()

    // MARK: - Multi-server method (uses ServerConfig; preferred for alljamfStatus)

    func get(server: ServerConfig, endpoint: String, completion: @escaping (_ notificationAlerts: [[String: Any]]) -> Void) {
        Task {
            let tokenString = await TokenManager.shared.ensureToken(for: server)
            guard let tokenString, !tokenString.isEmpty,
                  await TokenManager.shared.token(for: server.url)?.authMessage == "success" else {
                completion([])
                return
            }

            URLCache.shared.removeAllCachedResponses()
            var workingUrlString = "\(server.url)/api/\(endpoint)"
            workingUrlString     = workingUrlString.replacingOccurrences(of: "//api", with: "/api")

            self.theUapiQ.maxConcurrentOperationCount = 1
            self.theUapiQ.addOperation {
                URLCache.shared.removeAllCachedResponses()
                guard let encodedURL = URL(string: workingUrlString) else {
                    completion([])
                    return
                }
                var request = URLRequest(url: encodedURL)
                request.httpMethod = "GET"
                request.setValue("Bearer \(tokenString)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue(AppInfo.userAgentHeader, forHTTPHeaderField: "User-Agent")

                let session = Foundation.URLSession(configuration: .default, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
                let task = session.dataTask(with: request) { data, response, error in
                    guard let httpResponse = response as? HTTPURLResponse else {
                        Logger.jpapi.info("[\(server.name, privacy: .public)] error: \(error?.localizedDescription ?? "unknown", privacy: .public)")
                        completion([])
                        return
                    }
                    if (200...299).contains(httpResponse.statusCode) {
                        do {
                            if let json = try JSONSerialization.jsonObject(with: data ?? Data(), options: .allowFragments) as? [[String: Any]] {
                                completion(json)
                            } else {
                                Logger.jpapi.info("[\(server.name, privacy: .public)] empty notifications response")
                                completion([])
                            }
                        } catch {
                            Logger.jpapi.info("[\(server.name, privacy: .public)] JSON parse error: \(error.localizedDescription, privacy: .public)")
                            completion([])
                        }
                    } else {
                        Logger.jpapi.debug("[\(server.name, privacy: .public)] \(endpoint, privacy: .public) error \(httpResponse.statusCode, privacy: .public)")
                        completion([])
                    }
                }
                task.resume()
            }
        }
    }

    // MARK: - Legacy single-server method (backward compat)

    func get(endpoint: String, completion: @escaping (_ notificationAlerts: [Dictionary<String,Any>]) -> Void) {
                
        Task {
            if await TokenManager.shared.tokenInfo?.renewToken ?? true || !JamfProServer.validToken {
                await TokenManager.shared.setToken(serverUrl: JamfProServer.url, username: JamfProServer.username.lowercased(), password: JamfProServer.password)
            }
            
            if await TokenManager.shared.tokenInfo?.authMessage ?? "" == "success" {
                
            URLCache.shared.removeAllCachedResponses()
            
            var workingUrlString = "\(JamfProServer.url)/api/\(endpoint)"
            workingUrlString     = workingUrlString.replacingOccurrences(of: "//api", with: "/api")
            
            self.theUapiQ.maxConcurrentOperationCount = 1
            
                self.theUapiQ.addOperation {
                    URLCache.shared.removeAllCachedResponses()
                    
                    let encodedURL = NSURL(string: workingUrlString)
                    let request = NSMutableURLRequest(url: encodedURL! as URL)
                    
                    let configuration  = URLSessionConfiguration.default
                    request.httpMethod = "GET"
                    
                    configuration.httpAdditionalHeaders = ["Authorization" : "Bearer \(JamfProServer.accessToken)", "Content-Type" : "application/json", "Accept" : "application/json", "User-Agent" : AppInfo.userAgentHeader]
                    
                    let session = Foundation.URLSession(configuration: configuration, delegate: self as URLSessionDelegate, delegateQueue: OperationQueue.main)
                    
                    let task = session.dataTask(with: request as URLRequest, completionHandler: {
                        (data, response, error) -> Void in
                        if let httpResponse = response as? HTTPURLResponse {
                            if httpResponse.statusCode >= 200 && httpResponse.statusCode <= 299 {
                                do {
                                    let json = try JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                                    if let notificationsDictArray = json as? [[String: Any]] {
                                        completion(notificationsDictArray)
                                        return
                                    } else {
                                        Logger.jpapi.info("An error creating notifications array")
                                        let dataString = String(data: data!, encoding: .utf8) ?? "No data"
                                        Logger.jpapi.info("returned data: \(dataString, privacy: .public)")
                                        completion([])
                                        return
                                    }
                                } catch {
                                    Logger.jpapi.info("An error parsing notification data occurred: \(error.localizedDescription, privacy: .public)")
                                }
                            } else {    // if httpResponse.statusCode <200 or >299
                                Logger.jpapi.debug("\(endpoint, privacy: .public) - get response error: \(httpResponse.statusCode, privacy: .public)")
                                if httpResponse.statusCode == 401 {
                                    JamfProServer.accessToken = ""
                                    JamfProServer.validToken = false
                                }
                                completion([])
                                return
                            }
                        } else {
                            Logger.jpapi.info("An error occurred: \(error!.localizedDescription, privacy: .public)")
                        }
                    })
                    task.resume()
                }
            }
        }
    }   // func get - end
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping(  URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
    
}

