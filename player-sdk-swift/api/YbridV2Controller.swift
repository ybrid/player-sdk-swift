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


class YbridV2Controller : ApiController {
    
    let encoder = JSONEncoder()
    var token:String?
    
    init(session:YbridSession) {
        self.encoder.dateEncodingStrategy = .formatted(Formatter.iso8601withMilliSeconds)
        super.init(session:session, version: .ybridV2)
    }
    
    override func connect() throws {
        if connected {
            return
        }
        
        if !valid {
            throw ApiError(ErrorKind.invalidSession, "session is not valid.")
        }
        
        Logger.api.debug("creating ybrid session")
        
        let sessionObj = try ctrlRequest(ctrlPath: "ctrl/v2/session/create", actionString: "create")
        try accecpt(response: sessionObj)
        connected = true
        
        Logger.api.debug("start date is \(Formatter.iso8601withMilliSeconds.string(from: sessionObj.startDate))")
    }
    
    override func disconnect() {
        if !connected {
            return
        }
        Logger.api.debug("closing ybrid session")
        
        do {
            let sessionObj = try ctrlRequest(ctrlPath: "ctrl/v2/session/close", actionString: "close")
            try accecpt(response: sessionObj)
            connected = false
            
            Logger.api.debug("start date was \(Formatter.iso8601withMilliSeconds.string(from: sessionObj.startDate))")
            
        } catch {
            Logger.api.error(error.localizedDescription)
        }
    }
    
    func info() {
        if !connected {
            Logger.api.error("no connected ybrid session")
            return
        }
        Logger.api.notice("getting info about ybrid session")
        
        do {
            let sessionObj = try ctrlRequest(ctrlPath: "ctrl/v2/session/info", actionString: "get info")
            try accecpt(response: sessionObj)
            
        } catch {
            Logger.api.error(error.localizedDescription)
        }
    }

    
    private func accecpt(response:YbridSessionObject) throws {
        token = response.sessionId
        //            updateBouquet(response.getRawBouquet());
        session.metadata = response.metadata // This must be after updateBouquet() has been called.
        playbackUri = response.playout.playbackURI
        baseUrl = response.playout.baseURL
        //            updatePlayout(response.getRawPlayout());
        //            updateSwapInfo(response.getRawSwapInfo());
        if !response.valid {
            valid = false
        }
        //                   if (session.getActiveWorkarounds().get(Workaround.WORKAROUND_BAD_PACKED_RESPONSE).toBool(false)) {
        //                       LOGGER.warning("Invalid response from server but ignored by enabled WORKAROUND_BAD_PACKED_RESPONSE");
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
            let responseString = String(data: try encoder.encode(sessionObj), encoding: .utf8) ?? "(no response struct)"
            Logger.api.debug("__responseObject is \(responseString)")
            return sessionObj
        } catch {
            Logger.api.error(error.localizedDescription)
            throw ApiError(ErrorKind.invalidResponse, "cannot \(actionString) ybrid session", error)
        }
    }
    
    func logMetadata() {
        
        if let metadata = session.metadata {
            do {
                let metadataData = try encoder.encode(metadata.currentItem)
                let metadataString = String(data: metadataData, encoding: .utf8)!
                Logger.api.debug("current item is \(metadataString)")
            } catch {
                Logger.api.error("cannot log metadata")
            }
        }
    }
    
}
