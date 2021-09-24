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


    weak var ybridSession:YbridSession?
    init(notifyError:@escaping ((ErrorSeverity, SessionError)->())) {
        self.notify = notifyError
        super.init(version: .ybridV2)
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
        ybridSession?.accecpt(response: sessionObj)
        super.connected = true
    }
    
    override func disconnect() {
        if !super.connected {
            return
        }
        Logger.session.info("closing ybrid session")
        
        do {
            let sessionObj = try sessionRequest(ctrlPath: "ctrl/v2/session/close", actionString: "close")
            ybridSession?.accecpt(response: sessionObj)
            super.connected = false
        } catch {
            Logger.session.error(error.localizedDescription)
        }
    }
    
    func metadata() {
        guard super.connected else {
            Logger.session.error("no connected ybrid session")
            return
        }
        Logger.session.debug("getting metadata from ybrid session")
        
    }
    
    func info() {
        guard super.connected else {
            Logger.session.error("no connected ybrid session")
            return
        }
        Logger.session.debug("getting info about ybrid session")
        
        do {
            let sessionObj = try sessionRequest(ctrlPath: "ctrl/v2/session/info", actionString: "get info")
            ybridSession?.accecpt(response: sessionObj)
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
            ybridSession?.accept(showMeta: showMetaObj)
        } catch {
            Logger.session.error(error.localizedDescription)
        }
    }

    
    /// visible for tests
    func reconnect() throws {
        Logger.session.info("reconnecting ybrid session")
        let sessionObj = try createSessionRequest(ctrlPath: "ctrl/v2/session/create", actionString: "reconnect")
        ybridSession?.accecpt(response: sessionObj)
        super.connected = true
    }
    
    // MARK: bit rate
    
    func limitBitRate(maxBps:Int32) {
        guard super.connected else {
            Logger.session.error("no connected ybrid session")
            return
        }
        Logger.session.debug("request max bit-rate to \(maxBps)")
        
        do {
            let bitRate = URLQueryItem(name: "value", value: "\(maxBps)")
            let bitrateObj = try changeBitrateRequest(ctrlPath: "ctrl/v2/session/set-max-bit-rate", actionString: "limit bit-rate to \(maxBps)", queryParam: bitRate)
            ybridSession?.accept(maxBitrate: bitrateObj.maxBitRate)
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
            ybridSession?.accept(winded: windedObj)
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
            ybridSession?.accept(winded: windedObj)
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
            ybridSession?.accept(winded: windedObj)
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
            ybridSession?.accept(winded: windedObj)
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
        guard ybridSession?.state.swaps != 0 else {
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
            ybridSession?.accept(swapped: swappedObj)
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
            ybridSession?.accept(ybridBouquet: swappedObj.bouquet)
            if !super.valid {
                try reconnect()
            }
        } catch {
            Logger.session.error(error.localizedDescription)
            return false
        }
        return true
    }
    
    // MARK: all requests
    
    private func createSessionRequest(ctrlPath:String, actionString:String) throws -> YbridSessionObject {
        guard let state = ybridSession?.state else {
            throw SessionError(.noSession, "cannot \(actionString), no connected ybrid session or state")
        }
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
        guard super.connected, let state = ybridSession?.state else {
            throw SessionError(.noSession, "cannot \(actionString), no connected ybrid session or state")
        }
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
        guard super.connected, let state = ybridSession?.state else {
            throw SessionError(.noSession, "cannot \(actionString), no connected ybrid session or state")
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
        guard super.connected, let state = ybridSession?.state else {
            throw SessionError(.noSession, "cannot \(actionString), no connected ybrid session or state")
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
        guard super.connected, let state = ybridSession?.state else {
            throw SessionError(.noSession, "cannot \(actionString), no connected ybrid session or state")
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
        guard super.connected, let state = ybridSession?.state else {
            throw SessionError(.noSession, "cannot \(actionString), no connected ybrid session or state")
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
        guard var ctrlUrl = URLComponents(string: baseUrl.appendingPathComponent(ctrlPath).absoluteString), let state = ybridSession?.state else {
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
