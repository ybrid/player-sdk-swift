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


class YbridV2Driver : MediaDriver {
    
    let encoder = JSONEncoder()
    var token:String?
    var startDate:Date? { didSet {
        if let start = startDate, startDate != oldValue {
            Logger.controlling.debug("start date is \(Formatter.iso8601withMilliSeconds.string(from: start))")
        }
    }
    }
    var ybridMetadata:YbridV2Metadata?
    
    init(session:MediaSession) {
        self.encoder.dateEncodingStrategy = .formatted(Formatter.iso8601withMilliSeconds)
        super.init(session:session, version: .ybridV2)
    }
    
    override func connect() throws {
        if connected {
            return
        }
 
        if !valid {
            throw SessionError(ErrorKind.invalidSession, "session is not valid.")
        }
        
        Logger.controlling.debug("creating ybrid session")
        
        let sessionObj = try ctrlRequest(ctrlPath: "ctrl/v2/session/create", actionString: "create")
        accecpt(response: sessionObj)
        connected = true
    }
    
    override func disconnect() {
        if !connected {
            return
        }
        Logger.controlling.debug("closing ybrid session")
        
        do {
            let sessionObj = try ctrlRequest(ctrlPath: "ctrl/v2/session/close", actionString: "close")
            accecpt(response: sessionObj)
            connected = false
        } catch {
            Logger.controlling.error(error.localizedDescription)
        }
    }
    
    func info() {
        if !connected {
            Logger.controlling.error("no connected ybrid session")
            return
        }
        Logger.controlling.debug("getting info about ybrid session")
        
        do {
            let sessionObj = try ctrlRequest(ctrlPath: "ctrl/v2/session/info", actionString: "get info")
            accecpt(response: sessionObj)
            if !valid {
                try reconnect()
            }
        } catch {
            Logger.controlling.error(error.localizedDescription)
        }
    }
    
    private func reconnect() throws {
        Logger.controlling.info("reconnecting ybrid session")
        let sessionObj = try ctrlRequest(ctrlPath: "ctrl/v2/session/create", actionString: "reconnect")
        accecpt(response: sessionObj)
        connected = true
    }
    
    private func accecpt(response:YbridSessionObject) {
        valid = response.valid
        token = response.sessionId
        // updateBouquet(response.getRawBouquet());
        ybridMetadata = response.metadata  // Metadata must be accepted after bouquet

        
        if let playout = response.playout {
            playbackUri = playout.playbackURI
            baseUrl = playout.baseURL
            offsetToLiveS = Double(playout.offsetToLive) / 1000
            //            updatePlayout(response.getRawPlayout());
            //            updateSwapInfo(response.getRawSwapInfo());
        }
        startDate = response.startDate
    
        //                   if (session.getActiveWorkarounds().get(Workaround.WORKAROUND_BAD_PACKED_RESPONSE).toBool(false)) {
        //                       LOGGER.warning("Invalid response from server but ignored by enabled WORKAROUND_BAD_PACKED_RESPONSE");
    }
    
    private func ctrlRequest(ctrlPath:String, actionString:String) throws -> YbridSessionObject {
        guard var ctrlUrl = URLComponents(string: baseUrl.appendingPathComponent(ctrlPath).absoluteString) else {
            throw SessionError(ErrorKind.invalidResponse, "cannot \(actionString) ybrid session")
        }
        if let token = token {
            ctrlUrl.query = "session-id=\(token)"
        }
        guard let url = ctrlUrl.url else {
            throw SessionError(ErrorKind.invalidResponse, "cannot \(actionString) ybrid session")
        }
        
        do {
            guard let result = try JsonRequest(url: url).performPostSync(responseType: YbridSessionResponse.self) else {
                throw SessionError(ErrorKind.invalidResponse, "no json result")
            }
            let sessionObj = result.__responseObject
            let responseString = String(data: try encoder.encode(sessionObj), encoding: .utf8) ?? "(no response struct)"
            Logger.controlling.debug("__responseObject is \(responseString)")
            return sessionObj
        } catch {
            Logger.controlling.error(error.localizedDescription)
            throw SessionError(ErrorKind.invalidResponse, "cannot \(actionString) ybrid session", error)
        }
    }
    
    func logMetadata(_ data: YbridV2Metadata) {
        do {
            let currentItemData = try encoder.encode(data.currentItem)
            let metadataString = String(data: currentItemData, encoding: .utf8)!
            Logger.controlling.debug("current item is \(metadataString)")
        } catch {
            Logger.controlling.error("cannot log metadata")
        }
    }
    
}
