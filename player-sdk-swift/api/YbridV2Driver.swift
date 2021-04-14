//
// ApiDriver.swift
// player-sdk-swift
//
// Copyright (c) 2021 nacamar GmbH - Ybrid®, a Hybrid Dynamic Live Audio Technology
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import Foundation


class YbridV2Driver : ApiDriver {
    
    let apiVersion = ApiVersion.ybridV2
    let session:Session
    var baseUrl:URL
    var valid:Bool = true
    var connected:Bool = false { didSet {
        Logger.api.info("ybrid driver \(connected ? "connected" : "disconnected")")
    }}
    var playbackUri:String
    var token:String?
    
    init(session:Session){
        self.session = session
        self.playbackUri = session.endpoint.uri
        self.baseUrl = URL(string: session.endpoint.uri)!
    }
    
    func connect() throws {
        if connected {
            return
        }
        
        if !valid {
            throw ApiError(ErrorKind.invalidSession, "session is not valid.")
        }
                
        Logger.api.debug("creating ybrid session")
        
        let sessionObj = try ctrlRequest(ctrlPath: "ctrl/v2/session/create", actionString: "create")
        token = sessionObj.sessionId
        valid = sessionObj.valid
        playbackUri = sessionObj.playout.playbackURI
        baseUrl = sessionObj.playout.baseURL
        connected = true
    }
       
    func disconnect() {
        if !connected {
            return
        }
        Logger.api.debug("closing ybrid session")
        
        do {
            let sessionObj = try ctrlRequest(ctrlPath: "ctrl/v2/session/close", actionString: "close")
            valid = sessionObj.valid
            playbackUri = sessionObj.playout.playbackURI
            baseUrl = sessionObj.playout.baseURL
            connected = false
        } catch {
            Logger.api.error(error.localizedDescription)
        }
    }
    
    func info() throws {
        if !connected {
            Logger.api.error("no connected ybrid session")
            return
        }
        Logger.api.notice("getting info about ybrid session")
        
        do {
            let sessionObj = try ctrlRequest(ctrlPath: "ctrl/v2/session/info", actionString: "get info about")
            token = sessionObj.sessionId
            connected = sessionObj.valid
            playbackUri = sessionObj.playout.playbackURI
            baseUrl = sessionObj.playout.baseURL
        } catch {
            Logger.api.error(error.localizedDescription)
        }
    }
    
    private func ctrlRequest(ctrlPath:String, actionString:String) throws -> YbridSessionObject {
        guard var ctrlUrl = URLComponents(string: baseUrl.appendingPathComponent(ctrlPath).absoluteString) else {
            throw ApiError(ErrorKind.invalidResponse, "cannot \(actionString) ybrid session")
        }
        if let token = token {
            ctrlUrl.query = "session-id=\(token)"
        }
        guard let url = ctrlUrl.url else {
            throw ApiError(ErrorKind.invalidResponse, "cannot \(actionString) ybrid session")
        }
        
        do {
            guard let result = try JsonRequest(url: url).performPostSync(responseType: YbridSessionResponse.self) else {
                throw ApiError(ErrorKind.invalidResponse, "no json result")
            }
            let sessionObj = result.__responseObject
            Logger.api.debug(String(data: try JSONEncoder().encode(sessionObj), encoding: .utf8) ?? "(no ybrid struct)")
            return sessionObj
        } catch {
            Logger.api.error(error.localizedDescription)
            throw ApiError(ErrorKind.invalidResponse, "cannot \(actionString) ybrid session", error)
        }
    }
    
}
