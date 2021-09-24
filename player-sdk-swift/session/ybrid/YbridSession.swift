//
// YbridSession.swift
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


class AbstractSession {
    
    let state: MediaState
    let driver: MediaDriver
    
    init(state: MediaState, driver: MediaDriver) {
        self.state = state
        self.driver = driver
    }
    
    func connect() throws {
        try driver.connect()
    }
    
    func disconnect() {
        driver.disconnect()
    }
    
    func refresh() {
        fatalError(#function + " must be overridden")
    }
    
    func clearChanged(_ what: SubInfo) {
        state.clearChanged(what)
    }
    func hasChanged(_ what: SubInfo) -> Bool {
        return state.hasChanged(what)
    }
    
    func fetchMetadataSync(metadataIn: AbstractMetadata) {
        fatalError(#function + " must be overridden")
    }
}

class IcySession : AbstractSession {
    
    init(endpoint: MediaEndpoint, icy driver: MediaDriver) {
        let state = MediaState(endpoint)
        super.init(state: state, driver: driver)
    }
    
    override func fetchMetadataSync(metadataIn: AbstractMetadata) {
        state.metadata = metadataIn
    }
    
    override func refresh() {
    }
}

class YbridSession : AbstractSession {
    
    private let encoder = JSONEncoder()
    let v2Driver:YbridV2Driver // visible for unit testing
    var timeshifting:Bool = false
    
    init(endpoint: MediaEndpoint, v2 driver: YbridV2Driver) {
        let state = MediaState(endpoint)
        self.v2Driver = driver
        super.init(state: state, driver: driver)
        self.encoder.dateEncodingStrategy = .formatted(Formatter.iso8601withMillis)
        driver.ybridSession = self
    }
    
    override func fetchMetadataSync(metadataIn: AbstractMetadata) {
        if timeshifting {
            v2Driver.info()
        } else {
            if let streamUrl = (metadataIn as? IcyMetadata)?.streamUrl {
                v2Driver.showMeta(streamUrl)
            } else {
                v2Driver.info()
            }
        }
    }
    
    override func refresh() {
        v2Driver.info()
    }
    
    
    func maxBitRate(to bps:Int32) {
        v2Driver.limitBitRate(maxBps: bps)
    }
    
    func wind(by:TimeInterval) -> Bool {
        return v2Driver.wind(by: by)
    }
    func windToLive() -> Bool {
        return v2Driver.windToLive()
    }
    func wind(to:Date) -> Bool {
        return v2Driver.wind(to:to)
    }
    func skipForward(_ type:ItemType?) -> Bool {
        return v2Driver.skipItem(true, type)
    }
    func skipBackward(_ type:ItemType?) -> Bool {
        return v2Driver.skipItem(false, type)
    }
    func swapItem() -> Bool {
        return v2Driver.swapItem(.end2end)
    }
    func swapService(id:String) -> Bool {
        return v2Driver.swapService(id: id)
    }
    
    
    // MARK: accept response objects
    
    func accecpt(response:YbridSessionObject) {
        driver.valid = response.valid
        state.startDate = response.startDate
        state.token = response.sessionId
        
        if let playout = response.playout {
            state.playbackUri = playout.playbackURI
            state.baseUrl = playout.baseURL
            accept(offset: playout.offsetToLive)
            accept(currentBitRate: playout.currentBitRate)
            accept(maxBitrate: playout.maxBitRate)
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
    
    func accept(showMeta:YbridShowMeta) {
        accept(newMetadata: YbridV2Metadata(currentItem: showMeta.currentItem, nextItem: showMeta.nextItem, station: showMeta.station) )
        accept(swapped:showMeta.swapInfo)
        accept(currentBitRate: showMeta.currentBitRate)
        // 2021-08-25 not using showMeta.timeToNextItemMillis
    }
    
    func accept(winded:YbridWindedObject) {
        accept(offset:winded.totalOffset)
        accept(newCurrentItem: winded.newCurrentItem)
    }

    func accept(newMetadata:YbridV2Metadata) {
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
    
    func accept(swapped:YbridSwapInfo) {
        state.swaps = swapped.swapsLeft
    }
    
    func accept(ybridBouquet:YbridBouquet) {
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
    func accept(maxBitrate: Int32) {
        if maxBitrate != -1 {
            state.maxBitRate = maxBitrate
        }
    }
    func accept(currentBitRate: Int32) {
        if currentBitRate != -1 {
            state.currentBitRate = currentBitRate
        }
    }
}

