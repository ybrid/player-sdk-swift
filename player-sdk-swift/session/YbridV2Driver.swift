//
// YbridV2Driver.swift
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
            DispatchQueue.global().async {
                super.listener?.offsetToLiveChanged(self.offsetToLiveS)
            }
        }
    }}
    
    var ybridBouquet:YbridBouquet? { didSet {
        if let ybridBouquet = ybridBouquet, ybridBouquet != oldValue {
            do {
                if Logger.verbose == true {
                    let bouquetData = try encoder.encode(ybridBouquet)
                    let bouquetString = String(data: bouquetData, encoding: .utf8)!
                    Logger.session.debug("current bouquet is \(bouquetString)")
                }
                super.bouquet = try Bouquet(bouquet: ybridBouquet)
            } catch {
                Logger.session.error(error.localizedDescription)
            }
        }
    }}
    
    var ybridMetadata:YbridV2Metadata? { didSet {
        if let data = ybridMetadata, oldValue != ybridMetadata {
            if Logger.verbose == true {
                do {
                    let currentItemData = try encoder.encode(data.currentItem)
                    let metadataString = String(data: currentItemData, encoding: .utf8)!
                    Logger.session.debug("current item is \(metadataString)")
                } catch {
                    Logger.session.error("cannot log metadata")
                }
            }
        }
    }}
    
    var swapsLeft:Int? { didSet {
        if let swaps = swapsLeft, swaps != oldValue {
            DispatchQueue.global().async {
                super.listener?.swapsChanged(swaps)
            }
        }
    }}
    
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
        
        Logger.session.info("creating ybrid session")
        
        let sessionObj = try createSessionRequest(ctrlPath: "ctrl/v2/session/create", actionString: "create")
        accecpt(response: sessionObj)
        connected = true
    }
    
    override func disconnect() {
        if !connected {
            return
        }
        Logger.session.info("closing ybrid session")
        
        do {
            let sessionObj = try sessionRequest(ctrlPath: "ctrl/v2/session/close", actionString: "close")
            accecpt(response: sessionObj)
            connected = false
        } catch {
            Logger.session.error(error.localizedDescription)
        }
    }
    
    func info() {
        guard connected else {
            Logger.session.error("no connected ybrid session")
            return
        }
        Logger.session.debug("getting info about ybrid session")
        
        do {
            let sessionObj = try sessionRequest(ctrlPath: "ctrl/v2/session/info", actionString: "get info")
            accecpt(response: sessionObj)
            if !valid {
                try reconnect()
            }
        } catch {
            Logger.session.error(error.localizedDescription)
        }
    }
    
    
    
    func showMeta(_ streamUrl:String) {
        guard connected else {
            Logger.session.error("no connected ybrid session")
            return
        }
        Logger.session.debug("getting info about ybrid session")
        
        do {
            guard let ctrlUrl = URL(string: streamUrl) else {
                throw SessionError(ErrorKind.invalidUri, "cannot request \(streamUrl)")
            }
            
            guard let showMetaObj:YbridShowMeta = try JsonRequest(url: ctrlUrl).performPostSync(responseType: YbridShowMeta.self) else {
                throw SessionError(ErrorKind.invalidResponse, "no result for show meta")
            }
            Logger.session.debug("show-meta is \(showMetaObj)")
            accecpt(showMeta: showMetaObj)
            if !valid {
                try reconnect()
            }
        } catch {
            Logger.session.error(error.localizedDescription)
        }
    }

    
    /// visible for tests
    func reconnect() throws {
        Logger.session.info("reconnecting ybrid session")
        let sessionObj = try createSessionRequest(ctrlPath: "ctrl/v2/session/create", actionString: "reconnect")
        accecpt(response: sessionObj)
        connected = true
    }
    
    // MARK: winding
    
    func wind(by:TimeInterval) -> Bool {
        do {
            let millis = Int(by * 1000)
            let windByMillis = URLQueryItem(name: "duration", value: "\(millis)")
            let windedObj = try windRequest(ctrlPath: "ctrl/v2/playout/wind", actionString: "wind by \(by.S)", queryParam: windByMillis)
            accecpt(winded: windedObj)
            if !valid {
                try reconnect()
            }
        } catch {
            Logger.session.error(error.localizedDescription)
            return false
        }
        return true
    }
    
    func windToLive() -> Bool {
        do {
            let windedObj = try windRequest(ctrlPath: "ctrl/v2/playout/wind/back-to-live", actionString: "wind to live")
            accecpt(winded: windedObj)
            if !valid {
                try reconnect()
            }
        } catch {
            Logger.session.error(error.localizedDescription)
            return false
        }
        return true
    }
    
    func wind(to:Date) -> Bool {
        do {
            let dateDouble = to.timeIntervalSince1970
            let tsString = String(Int64(dateDouble*1000))
            let tsQuery = URLQueryItem(name: "ts", value: tsString)
            let windedObj = try windRequest(ctrlPath: "ctrl/v2/playout/wind", actionString: "wind to \(to)", queryParam: tsQuery)
            accecpt(winded: windedObj)
            if !valid {
                try reconnect()
            }
        } catch {
            Logger.session.error(error.localizedDescription)
            return false
        }
        return true
    }
    
    func skipItem(_ forwards:Bool, _ type:ItemType?) -> Bool {

        let direction = forwards ? "forwards":"backwards"
        let ctrlPath = "ctrl/v2/playout/skip/" + direction
        do {
            let windedObj:YbridWindedObject
            if let type = type, type != ItemType.UNKNOWN {
                let skipType = URLQueryItem(name: "item-type", value: type.rawValue)
                windedObj = try windRequest(ctrlPath: ctrlPath, actionString: "skip \(direction) to \(type)", queryParam: skipType)
            } else {
                windedObj = try windRequest(ctrlPath: ctrlPath, actionString: "skip \(direction) to item")
            }
            accecpt(winded: windedObj)
            if !valid {
                try reconnect()
            }
        } catch {
            Logger.session.error(error.localizedDescription)
            return false
        }
        return true
    }
    
    // MARK: swapping item
    
    enum SwapMode : String {
        case end2end /// Beginning of alternative content will be skipped to fit to the left main items duration.
        case fade2end /// Alternative content starts from the beginning and will become faded out at the end.
    }
    
    func swapItem(_ mode: SwapMode? = nil) -> Bool {

        var actionString = "swap item"
        guard swapsLeft != 0 else {
            let warning = SessionError(ErrorKind.noSwapsLeft, actionString + " not available")
            super.notify(.recoverable, warning)
            Logger.session.notice(actionString + " not available")
            return false
        }
        
        let swappedObj:YbridSwapInfo
        do {
            if let mode = mode {
                actionString += " with mode \(mode.rawValue)"
                let modeQuery = URLQueryItem(name: "mode", value: mode.rawValue)
                swappedObj = try swapItemRequest(ctrlPath: "ctrl/v2/playout/swap/item", actionString: actionString, queryParam: modeQuery)
            } else {
                swappedObj = try swapItemRequest(ctrlPath: "ctrl/v2/playout/swap/item", actionString: actionString)
            }
            accecpt(swapped: swappedObj)
            if !valid {
                try reconnect()
            }
        } catch {
            Logger.session.error(error.localizedDescription)
            return false
        }
        return true
    }

     // MARK: swap service
    
    func swapService(id:String) -> Bool {

        do {
            let serviceQuery = URLQueryItem(name: "service-id", value: id)
            let swappedObj = try swapServiceRequest(ctrlPath: "ctrl/v2/playout/swap/service", actionString: "swap to service \(id)", queryParam: serviceQuery)
            accecpt(bouquetObj: swappedObj)
            if !valid {
                try reconnect()
            }
        } catch {
            Logger.session.error(error.localizedDescription)
            return false
        }
        return true
    }

    // MARK: accept response objects
    
    private func accecpt(response:YbridSessionObject) {
        valid = response.valid
        token = response.sessionId
        
        if let playout = response.playout {
            playbackUri = playout.playbackURI
            baseUrl = playout.baseURL
            accept(offset: playout.offsetToLive)
        }
        
        ybridBouquet = response.bouquet
        ybridMetadata = response.metadata  // Metadata must be accepted after bouquet
        startDate = response.startDate
        if let swapInfo = response.swapInfo {
            accecpt(swapped: swapInfo)
        }

        //                   if (session.getActiveWorkarounds().get(Workaround.WORKAROUND_BAD_PACKED_RESPONSE).toBool(false)) {
        //                       LOGGER.warning("Invalid response from server but ignored by enabled WORKAROUND_BAD_PACKED_RESPONSE");
    }
    
    private func accecpt(showMeta:YbridShowMeta) {
//        showMeta.currentBitRate
        ybridMetadata = YbridV2Metadata(currentItem: showMeta.currentItem, nextItem: showMeta.nextItem, station: showMeta.station)
        accecpt(swapped:showMeta.swapInfo)
//        showMeta.timeToNextItemMillis
    }
    
    private func accecpt(winded:YbridWindedObject) {

        accept(offset:winded.totalOffset)
        
        if let oldMetadata = ybridMetadata {
            let newMetatdata = YbridV2Metadata(currentItem: winded.newCurrentItem, nextItem: oldMetadata.nextItem, station: oldMetadata.station)
            ybridMetadata = newMetatdata
        } else {
            ybridMetadata = YbridV2Metadata(currentItem: winded.newCurrentItem, nextItem: YbridItem(id: "", artist: "", title: "", description: "", durationMillis: 0, type: ItemType.UNKNOWN.rawValue), station: YbridStation(genre: "", name: ""))
        }
    }
    
    private func accecpt(swapped:YbridSwapInfo) {
        swapsLeft = swapped.swapsLeft
    }
    
    private func accecpt(bouquetObj:YbridBouquetObject) {
        ybridBouquet = bouquetObj.bouquet
    }
    
    func accept(offset: Int) {
        offsetToLiveS = Double(offset) / 1000
    }
    
    // MARK: all requests
    
    
    private func createSessionRequest(ctrlPath:String, actionString:String) throws -> YbridSessionObject {
        do {
            let result:YbridSessionResponse = try jsonRequest(baseUrl: endpointUri, ctrlPath: ctrlPath, actionString: actionString)

            if Logger.verbose { Logger.session.debug(String(describing: result.__responseObject)) }
            return result.__responseObject
    
        } catch {
            let cannot = SessionError(ErrorKind.invalidResponse, "cannot \(actionString) ybrid session", error)
            super.notify(ErrorSeverity.fatal, cannot)
            throw cannot
        }
    }

    
    private func sessionRequest(ctrlPath:String, actionString:String) throws -> YbridSessionObject {
        
        do {
            let result:YbridSessionResponse = try jsonRequest(baseUrl: baseUrl, ctrlPath: ctrlPath, actionString: actionString)

            if Logger.verbose { Logger.session.debug(String(describing: result.__responseObject)) }
            return result.__responseObject
    
        } catch {
            let cannot = SessionError(ErrorKind.invalidResponse, "cannot \(actionString) ybrid session", error)
            super.notify(ErrorSeverity.fatal, cannot)
            throw cannot
        }
    }

    private func windRequest(ctrlPath:String, actionString:String, queryParam:URLQueryItem? = nil) throws -> YbridWindedObject {
        guard connected else {
            throw SessionError(.noSession, "cannot \(actionString), no connected ybrid session")
        }
        Logger.session.info(actionString)
        do {
            let result:YbridWindResponse = try jsonRequest(baseUrl: baseUrl, ctrlPath: ctrlPath, actionString: actionString, queryParam: queryParam)

            let windedObject = result.__responseObject
            if Logger.verbose { Logger.session.debug(String(describing: windedObject)) }
            return windedObject
        } catch {
            let cannot = SessionError(ErrorKind.invalidResponse, "cannot \(actionString)", error)
            super.notify(ErrorSeverity.fatal, cannot)
            throw cannot
        }
    }
    
    private func swapItemRequest(ctrlPath:String, actionString:String, queryParam:URLQueryItem? = nil) throws -> YbridSwapInfo {
        guard connected else {
            throw SessionError(.noSession, "cannot \(actionString), no connected ybrid session")
        }
        Logger.session.info(actionString)
        do {
            let result:YbridSwapItemResponse = try jsonRequest(baseUrl: baseUrl, ctrlPath: ctrlPath, actionString: actionString, queryParam: queryParam)

            let swappedObject = result.__responseObject
            if Logger.verbose { Logger.session.debug(String(describing: swappedObject)) }
            return swappedObject
        } catch {
            let cannot = SessionError(ErrorKind.invalidResponse, "cannot \(actionString)", error)
            super.notify(ErrorSeverity.fatal, cannot)
            throw cannot
        }
    }

    private func swapServiceRequest(ctrlPath:String, actionString:String, queryParam:URLQueryItem? = nil) throws -> YbridBouquetObject {
        guard connected else {
            throw SessionError(.noSession, "cannot \(actionString), no connected ybrid session")
        }
        Logger.session.info(actionString)
        do {
            let result:YbridSwapServiceResponse = try jsonRequest(baseUrl: baseUrl, ctrlPath: ctrlPath, actionString: actionString, queryParam: queryParam)

            let swappedObject = result.__responseObject
            if Logger.verbose { Logger.session.debug(String(describing: swappedObject)) }
            return swappedObject
        } catch {
            let cannot = SessionError(ErrorKind.invalidResponse, "cannot \(actionString)", error)
            super.notify(ErrorSeverity.fatal, cannot)
            throw cannot
        }
    }

    private func jsonRequest<T:Decodable>(baseUrl: URL, ctrlPath:String, actionString:String, queryParam:URLQueryItem? = nil) throws -> T {
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
         
        guard let result = try JsonRequest(url: url).performPostSync(responseType: T.self) else {
            throw SessionError(ErrorKind.invalidResponse, "no result for \(actionString)")
        }
        return result
    }
}
