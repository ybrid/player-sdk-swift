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
            Logger.session.debug("start date is \(Formatter.iso8601withMillis.string(from: start))")
        }
    }}
    
    var offsetToLiveS:TimeInterval? { didSet {
        if oldValue != offsetToLiveS {
            listener?.offsetToLiveChanged(offsetToLiveS)
        }
    }}
    var ybridMetadata:YbridV2Metadata?
    
    weak var listener:YbridControlListener?
    
    init(session:MediaSession) {
        self.encoder.dateEncodingStrategy = .formatted(Formatter.iso8601withMillis)
        super.init(session:session, version: .ybridV2)
    }
    
    // MARK: session and metadata
    
    override func connect() throws {
        if connected {
            return
        }
 
        if !valid {
            throw SessionError(ErrorKind.invalidSession, "session is not valid.")
        }
        
        Logger.session.debug("creating ybrid session")
        
        let sessionObj = try ctrlRequest(ctrlPath: "ctrl/v2/session/create", actionString: "create")
        accecpt(response: sessionObj)
        connected = true
    }
    
    override func disconnect() {
        if !connected {
            return
        }
        Logger.session.debug("closing ybrid session")
        
        do {
            let sessionObj = try ctrlRequest(ctrlPath: "ctrl/v2/session/close", actionString: "close")
            accecpt(response: sessionObj)
            connected = false
        } catch {
            Logger.session.error(error.localizedDescription)
        }
    }
    
    func info() {
        if !connected {
            Logger.session.error("no connected ybrid session")
            return
        }
        Logger.session.debug("getting info about ybrid session")
        
        do {
            let sessionObj = try ctrlRequest(ctrlPath: "ctrl/v2/session/info", actionString: "get info")
            accecpt(response: sessionObj)
            if !valid {
                try reconnect()
            }
        } catch {
            Logger.session.error(error.localizedDescription)
        }
    }
    
    private func reconnect() throws {
        Logger.session.info("reconnecting ybrid session")
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

    
    private func ctrlRequest(ctrlPath:String, actionString:String, queryParam:URLQueryItem? = nil) throws -> YbridSessionObject {
        guard var ctrlUrl = URLComponents(string: baseUrl.appendingPathComponent(ctrlPath).absoluteString) else {
            throw SessionError(ErrorKind.invalidUri, "cannot request \(actionString) on \(baseUrl)")
        }
        var urlQueries:[URLQueryItem] = []
        let tokenQuery = URLQueryItem(name: "session-id", value: token)
        urlQueries.append(tokenQuery)
        if let queryParam = queryParam {
            urlQueries.append(queryParam)
        }
        ctrlUrl.queryItems = urlQueries
        guard let url = ctrlUrl.url else {
            throw SessionError(ErrorKind.invalidUri, "cannot request \(actionString) on \(ctrlUrl.debugDescription)")
        }
        
        do {
            guard let result:YbridSessionResponse = try JsonRequest(url: url).performPostSync(responseType: YbridSessionResponse.self) else {
                let error = SessionError(ErrorKind.invalidResponse, "no result for \(actionString)")
                listener?.error(ErrorSeverity.fatal, error)
                throw error
            }

            Logger.session.debug(String(describing: result.__responseObject))
            return result.__responseObject
    
        } catch {
            let cannot = SessionError(ErrorKind.invalidResponse, "cannot \(actionString) ybrid session", error)
            listener?.error(ErrorSeverity.fatal, cannot)
            throw cannot
        }
    }
    
    func logMetadata(_ data: YbridV2Metadata) {
        do {
            let currentItemData = try encoder.encode(data.currentItem)
            let metadataString = String(data: currentItemData, encoding: .utf8)!
            Logger.session.debug("current item is \(metadataString)")
        } catch {
            Logger.session.error("cannot log metadata")
        }
    }
    
    // MARK: winding
    
    func wind(by:TimeInterval) {

        if !connected {
            Logger.session.error("no connected ybrid session")
            return
        }
        Logger.session.info("wind by \(by.S)")
        
        do {
            let millis = Int(by * 1000)
            let windByMillis = URLQueryItem(name: "duration", value: "\(millis)")
            let windedObj = try windRequest(ctrlPath: "ctrl/v2/playout/wind", actionString: "wind \(by.S) seconds", queryParam: windByMillis)
            accecpt(winded: windedObj)
            if !valid {
                try reconnect()
            }
        } catch {
            Logger.session.error(error.localizedDescription)
        }
        
    }
    
    func windToLive() {

        if !connected {
            Logger.session.error("no connected ybrid session")
            return
        }
        Logger.session.info("wind to live")
        
        do {
            let windedObj = try windRequest(ctrlPath: "ctrl/v2/playout/wind/back-to-live", actionString: "wind to live")
            accecpt(winded: windedObj)
            if !valid {
                try reconnect()
            }
        } catch {
            
            Logger.session.error(error.localizedDescription)
        }
        
    }
    
    func wind(to:Date) {

        if !connected {
            Logger.session.error("no connected ybrid session")
            return
        }
        Logger.session.info("wind to \(to)")
        
        do {
            let dateDouble = to.timeIntervalSince1970
            let tsString = String(Int(dateDouble*1000))
            let tsQuery = URLQueryItem(name: "ts", value: tsString)
            let windedObj = try windRequest(ctrlPath: "ctrl/v2/playout/wind", actionString: "wind to \(to)", queryParam: tsQuery)
            accecpt(winded: windedObj)
            if !valid {
                try reconnect()
            }
        } catch {
            Logger.session.error(error.localizedDescription)
        }
        
    }
    
    
    func skipItem(_ forwards:Bool, _ type:ItemType?) {

        if !connected {
            Logger.session.error("no connected ybrid session")
            return
        }
        let direction = forwards ? "forwards":"backwards"
        
        do {
            let windedObj:YbridWindedObject
            if let type = type, type != ItemType.UNKNOWN {
                Logger.session.info("skip \(direction) to item of type \(type)")
                let skipType = URLQueryItem(name: "item-type", value: type.rawValue)
                windedObj = try windRequest(ctrlPath: "ctrl/v2/playout/skip/"+direction, actionString: "skip \(direction) to \(type)", queryParam: skipType)
            } else {
                Logger.session.info("skip \(direction) to item")
                windedObj = try windRequest(ctrlPath: "ctrl/v2/playout/skip/"+direction, actionString: "skip \(direction) to item")
            }
            accecpt(winded: windedObj)
            if !valid {
                try reconnect()
            }
        } catch {
            Logger.session.error(error.localizedDescription)
        }
        
    }
    
    private func windRequest(ctrlPath:String, actionString:String, queryParam:URLQueryItem? = nil) throws -> YbridWindedObject {
        guard var ctrlUrl = URLComponents(string: baseUrl.appendingPathComponent(ctrlPath).absoluteString) else {
            throw SessionError(ErrorKind.invalidUri, "cannot request \(actionString) on \(baseUrl)")
        }
        var urlQueries:[URLQueryItem] = []
        let tokenQuery = URLQueryItem(name: "session-id", value: token)
        urlQueries.append(tokenQuery)
        if let queryParam = queryParam {
            urlQueries.append(queryParam)
        }
        ctrlUrl.queryItems = urlQueries
        guard let url = ctrlUrl.url else {
            throw SessionError(ErrorKind.invalidUri, "cannot request \(actionString) on \(ctrlUrl.debugDescription)")
        }
         
        do {
            guard let result:YbridWindResponse = try JsonRequest(url: url).performPostSync(responseType: YbridWindResponse.self) else {
                let error = SessionError(ErrorKind.invalidResponse, "no result for \(actionString)")
                listener?.error(ErrorSeverity.fatal, error)
                throw error
            }

            let windedObject = result.__responseObject
            Logger.session.debug(String(describing: windedObject))
            return windedObject
        } catch {
            let cannot = SessionError(ErrorKind.invalidResponse, "cannot \(actionString)", error)
            listener?.error(ErrorSeverity.fatal, cannot)
            throw cannot
        }
    }

    private func accecpt(winded:YbridWindedObject) {
      
        offsetToLiveS = Double(winded.totalOffset) / 1000
//        ybridMetadata?.currentItem = winded.newCurrentItem
    }
    
    // MARK: swap
    
    enum SwapMode : String {
        case end2end /// Beginning of alternative content will be skipped to fit to the left main items duration.
        case fade2end /// Alternative content starts from the beginning and will become faded out at the end.
    }
    
    func swap() {

        if !connected {
            Logger.session.error("no connected ybrid session")
            return
        }
        Logger.session.info("swap item")
        
        do {
            let modeQuery = URLQueryItem(name: "mode", value: SwapMode.end2end.rawValue)
            let swappedObj = try swapRequest(ctrlPath: "ctrl/v2/playout/swap/item", actionString: "swap item", queryParam: modeQuery)
            accecpt(swapped: swappedObj)
            if !valid {
                try reconnect()
            }
        } catch {
            Logger.session.error(error.localizedDescription)
        }
        
    }

    private func accecpt(swapped:YbridSwapInfo) {
      // todo

    }
    
    
    private func swapRequest(ctrlPath:String, actionString:String, queryParam:URLQueryItem? = nil) throws -> YbridSwapInfo {
        guard var ctrlUrl = URLComponents(string: baseUrl.appendingPathComponent(ctrlPath).absoluteString) else {
            throw SessionError(ErrorKind.invalidUri, "cannot request \(actionString) on \(baseUrl)")
        }
        var urlQueries:[URLQueryItem] = []
        let tokenQuery = URLQueryItem(name: "session-id", value: token)
        urlQueries.append(tokenQuery)
        if let queryParam = queryParam {
            urlQueries.append(queryParam)
        }
        ctrlUrl.queryItems = urlQueries
        guard let url = ctrlUrl.url else {
            throw SessionError(ErrorKind.invalidUri, "cannot request \(actionString) on \(ctrlUrl.debugDescription)")
        }
         
        do {
            guard let result:YbridSwapItemResponse = try JsonRequest(url: url).performPostSync(responseType: YbridSwapItemResponse.self) else {
                let error = SessionError(ErrorKind.invalidResponse, "no result for \(actionString)")
                listener?.error(ErrorSeverity.fatal, error)
                throw error
            }

            let swappedObject = result.__responseObject
            Logger.session.debug(String(describing: swappedObject))
            return swappedObject
        } catch {
            let cannot = SessionError(ErrorKind.invalidResponse, "cannot \(actionString)", error)
            listener?.error(ErrorSeverity.fatal, cannot)
            throw cannot
        }
    }

    
    
    
}
