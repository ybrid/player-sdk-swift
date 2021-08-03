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

    
    init(session:MediaSession) {
        self.encoder.dateEncodingStrategy = .formatted(Formatter.iso8601withMillis)
        self.notify = session.notifyError
        super.init(session:session, version: .ybridV2)
    }
    
    let notify:((ErrorSeverity, SessionError)->())
    
    
    // MARK: session and metadata
    
    override func connect() throws {
        if super.connected {
            return
        }
 
        if !super.valid {
            throw SessionError(ErrorKind.invalidSession, "session is not valid.")
        }
        
        Logger.session.info("creating ybrid session")
        
        let sessionObj = try createSessionRequest(ctrlPath: "ctrl/v2/session/create", actionString: "create")
        accecpt(response: sessionObj)
        super.connected = true
    }
    
    override func disconnect() {
        if !super.connected {
            return
        }
        Logger.session.info("closing ybrid session")
        
        do {
            let sessionObj = try sessionRequest(ctrlPath: "ctrl/v2/session/close", actionString: "close")
            accecpt(response: sessionObj)
            super.connected = false
        } catch {
            Logger.session.error(error.localizedDescription)
        }
    }
    
    func info() {
        guard super.connected else {
            Logger.session.error("no connected ybrid session")
            return
        }
        Logger.session.debug("getting info about ybrid session")
        
        do {
            let sessionObj = try sessionRequest(ctrlPath: "ctrl/v2/session/info", actionString: "get info")
            accecpt(response: sessionObj)
            if !super.valid {
                try reconnect()
            }
        } catch {
            Logger.session.error(error.localizedDescription)
        }
    }
    
    
    
    func showMeta(_ streamUrl:String) {
        guard super.connected else {
            Logger.session.error("no connected ybrid session")
            return
        }
        Logger.session.debug("show metadata \(streamUrl)")
        
        do {
            guard let ctrlUrl = URL(string: streamUrl) else {
                throw SessionError(ErrorKind.invalidUri, "cannot request \(streamUrl)")
            }
            
            guard let showMetaObj:YbridShowMeta = try JsonRequest(url: ctrlUrl).performPostSync(responseType: YbridShowMeta.self) else {
                throw SessionError(ErrorKind.invalidResponse, "no result for show meta")
            }
//            Logger.session.debug("show-meta is \(showMetaObj)")
            accept(showMeta: showMetaObj)
        } catch {
            Logger.session.error(error.localizedDescription)
        }
    }

    
    /// visible for tests
    func reconnect() throws {
        Logger.session.info("reconnecting ybrid session")
        let sessionObj = try createSessionRequest(ctrlPath: "ctrl/v2/session/create", actionString: "reconnect")
        accecpt(response: sessionObj)
        super.connected = true
    }
    
    // MARK: bit rate
    
    func maxBitRate(bitPerSecond:Int32) {
        guard super.connected else {
            Logger.session.error("no connected ybrid session")
            return
        }
        Logger.session.debug("setting max bit rate ybrid session")
        
        do {
            let bitRate = URLQueryItem(name: "value", value: "\(bitPerSecond)")
            let bitrateObj = try changeBitrateRequest(ctrlPath: "ctrl/v2/session/set-max-bit-rate", actionString: "set bit rate", queryParam: bitRate)
            accept(bitrate: bitrateObj.maxBitRate)
            if !super.valid {
                try reconnect()
            }
        } catch {
            Logger.session.error(error.localizedDescription)
        }
    }
    
    
    
    
    // MARK: winding
    
    func wind(by:TimeInterval) -> Bool {
        do {
            let millis = Int(by * 1000)
            let windByMillis = URLQueryItem(name: "duration", value: "\(millis)")
            let windedObj = try windRequest(ctrlPath: "ctrl/v2/playout/wind", actionString: "wind by \(by.S)", queryParam: windByMillis)
            accept(winded: windedObj)
            if !super.valid {
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
            accept(winded: windedObj)
            if !super.valid {
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
            accept(winded: windedObj)
            if !super.valid {
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
            accept(winded: windedObj)
            if !super.valid {
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
        guard state.swaps != 0 else {
            let warning = SessionError(ErrorKind.noSwapsLeft, actionString + " not available")
            notify(.recoverable, warning)
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
            accept(swapped: swappedObj)
            if !super.valid {
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
            accept(ybridBouquet: swappedObj.bouquet)
            if !super.valid {
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
        super.valid = response.valid
        state.startDate = response.startDate
        state.token = response.sessionId
        
        if let playout = response.playout {
            state.playbackUri = playout.playbackURI
            state.baseUrl = playout.baseURL
            accept(offset: playout.offsetToLive)
            accept(bitrate: playout.maxBitRate)
        }
        if let ybridBouquet = response.bouquet {
            accept(ybridBouquet: ybridBouquet)
        }
        if let metadata = response.metadata {
            accept(newMetadata: metadata) // Metadata must be accepted after bouquet
        }
        if let swapInfo = response.swapInfo {
            accept(swapped: swapInfo)
        }
    }
    
    private func accept(showMeta:YbridShowMeta) {
//        accept(bitrate: showMeta.currentBitRate) // 2021-08-03
        accept(newMetadata: YbridV2Metadata(currentItem: showMeta.currentItem, nextItem: showMeta.nextItem, station: showMeta.station) )
        accept(swapped:showMeta.swapInfo)
//        showMeta.timeToNextItemMillis
    }
    
    private func accept(winded:YbridWindedObject) {
        accept(offset:winded.totalOffset)
        accept(newCurrentItem: winded.newCurrentItem)
    }

    private func accept(newMetadata:YbridV2Metadata) {
        let ybridV2Metadata = YbridV2Metadata(currentItem: newMetadata.currentItem, nextItem: newMetadata.nextItem, station: newMetadata.station)
        if Logger.verbose == true {
            do {
                let currentItemData = try encoder.encode(newMetadata.currentItem)
                let metadataString = String(data: currentItemData, encoding: .utf8)!
                Logger.session.debug("current item is \(metadataString)")
            } catch {
                Logger.session.error("cannot log metadata")
            }
        }
        let ybridMD = YbridMetadata(ybridV2: ybridV2Metadata)
        ybridMD.currentService = state.bouquet?.activeService
        state.metadata = ybridMD
    }
    
    private func accept(newCurrentItem:YbridItem) {
        let ybridV2Metadata = YbridV2Metadata(currentItem: newCurrentItem, nextItem: YbridItem(id: "", artist: "", title: "", description: "", durationMillis: 0, type: ItemType.UNKNOWN.rawValue), station: YbridStation(genre: "", name: ""))
        
        let ybridMD = YbridMetadata(ybridV2: ybridV2Metadata)
        ybridMD.currentService = state.bouquet?.activeService
        state.metadata = ybridMD
    }
    
    private func accept(swapped:YbridSwapInfo) {
        state.swaps = swapped.swapsLeft
    }
    
    private func accept(ybridBouquet:YbridBouquet) {
        do {
            if Logger.verbose == true {
                let bouquetData = try encoder.encode(ybridBouquet)
                let bouquetString = String(data: bouquetData, encoding: .utf8)!
                Logger.session.debug("current bouquet is \(bouquetString)")
            }
            state.bouquet = try Bouquet(bouquet: ybridBouquet)
        } catch {
            Logger.session.error(error.localizedDescription)
        }
    }
    func accept(offset: Int) {
        state.offset = Double(offset) / 1000
    }
    func accept(bitrate: Int32) {
        state.maxBitRate = bitrate
    }
    
    // MARK: all requests
    
    
    private func createSessionRequest(ctrlPath:String, actionString:String) throws -> YbridSessionObject {
        do {
            let result:YbridSessionResponse = try jsonRequest(baseUrl: state.endpointUri, ctrlPath: ctrlPath, actionString: actionString)

            if Logger.verbose { Logger.session.debug(String(describing: result.__responseObject)) }
            return result.__responseObject
    
        } catch {
            let cannot = SessionError(ErrorKind.invalidResponse, "cannot \(actionString) ybrid session", error)
            notify(ErrorSeverity.fatal, cannot)
            throw cannot
        }
    }

    
    private func sessionRequest(ctrlPath:String, actionString:String) throws -> YbridSessionObject {
        
        do {
            let result:YbridSessionResponse = try jsonRequest(baseUrl: state.baseUrl, ctrlPath: ctrlPath, actionString: actionString)

            if Logger.verbose { Logger.session.debug(String(describing: result.__responseObject)) }
            return result.__responseObject
    
        } catch {
            let cannot = SessionError(ErrorKind.invalidResponse, "cannot \(actionString) ybrid session", error)
            notify(ErrorSeverity.fatal, cannot)
            throw cannot
        }
    }

    private func windRequest(ctrlPath:String, actionString:String, queryParam:URLQueryItem? = nil) throws -> YbridWindedObject {
        guard super.connected else {
            throw SessionError(.noSession, "cannot \(actionString), no connected ybrid session")
        }
        Logger.session.info(actionString)
        do {
            let result:YbridWindResponse = try jsonRequest(baseUrl: state.baseUrl, ctrlPath: ctrlPath, actionString: actionString, queryParam: queryParam)

            let windedObject = result.__responseObject
            if Logger.verbose { Logger.session.debug(String(describing: windedObject)) }
            return windedObject
        } catch {
            let cannot = SessionError(ErrorKind.invalidResponse, "cannot \(actionString)", error)
            notify(ErrorSeverity.fatal, cannot)
            throw cannot
        }
    }
    
    private func swapItemRequest(ctrlPath:String, actionString:String, queryParam:URLQueryItem? = nil) throws -> YbridSwapInfo {
        guard super.connected else {
            throw SessionError(.noSession, "cannot \(actionString), no connected ybrid session")
        }
        Logger.session.info(actionString)
        do {
            let result:YbridSwapItemResponse = try jsonRequest(baseUrl: state.baseUrl, ctrlPath: ctrlPath, actionString: actionString, queryParam: queryParam)

            let swappedObject = result.__responseObject
            if Logger.verbose { Logger.session.debug(String(describing: swappedObject)) }
            return swappedObject
        } catch {
            let cannot = SessionError(ErrorKind.invalidResponse, "cannot \(actionString)", error)
            notify(ErrorSeverity.fatal, cannot)
            throw cannot
        }
    }

    private func swapServiceRequest(ctrlPath:String, actionString:String, queryParam:URLQueryItem? = nil) throws -> YbridBouquetObject {
        guard super.connected else {
            throw SessionError(.noSession, "cannot \(actionString), no connected ybrid session")
        }
        Logger.session.info(actionString)
        do {
            let result:YbridSwapServiceResponse = try jsonRequest(baseUrl: state.baseUrl, ctrlPath: ctrlPath, actionString: actionString, queryParam: queryParam)

            let swappedObject = result.__responseObject
            if Logger.verbose { Logger.session.debug(String(describing: swappedObject)) }
            return swappedObject
        } catch {
            let cannot = SessionError(ErrorKind.invalidResponse, "cannot \(actionString)", error)
            notify(ErrorSeverity.fatal, cannot)
            throw cannot
        }
    }

    private func changeBitrateRequest(ctrlPath:String, actionString:String, queryParam:URLQueryItem? = nil) throws -> YbridBitRate {
        guard super.connected else {
            throw SessionError(.noSession, "cannot \(actionString), no connected ybrid session")
        }
        Logger.session.info(actionString)
        do {
            let result:YbridBitrateResponse = try jsonRequest(baseUrl: state.baseUrl, ctrlPath: ctrlPath, actionString: actionString, queryParam: queryParam)

            let birateObject = result.__responseObject
            if Logger.verbose { Logger.session.debug(String(describing: birateObject)) }
            return birateObject
        } catch {
            let cannot = SessionError(ErrorKind.invalidResponse, "cannot \(actionString)", error)
            notify(ErrorSeverity.fatal, cannot)
            throw cannot
        }
    }

    private func jsonRequest<T:Decodable>(baseUrl: URL, ctrlPath:String, actionString:String, queryParam:URLQueryItem? = nil) throws -> T {
        guard var ctrlUrl = URLComponents(string: baseUrl.appendingPathComponent(ctrlPath).absoluteString) else {
            throw SessionError(ErrorKind.invalidUri, "cannot request \(actionString) on \(baseUrl)")
        }
        var urlQueries:[URLQueryItem] = []
        let tokenQuery = URLQueryItem(name: "session-id", value: state.token)
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
