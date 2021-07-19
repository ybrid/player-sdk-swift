//
// MediaSession.swift
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

// The session establishes the media control protocol with the server.
// It caches meta data and in future will offer media controllers to interact with.

import Foundation

public class MediaSession  {
       
    let endpoint:MediaEndpoint
    let factory = MediaControlFactory()
    var driver:MediaDriver?
     
    weak var playerListener:AudioPlayerListener?
    
    public var mediaProtocol:MediaProtocol? { get {
        return driver?.mediaProtocol
    }}

    public var playbackUri:String { get {
        return driver?.state.playbackUri ?? endpoint.uri
    }}
    
    private var metadataDict = ThreadsafeDictionary<UUID,AbstractMetadata>(
        DispatchQueue(label: "io.ybrid.metadata.maintaining", qos: PlayerContext.processingPriority)
    )
    
    var swaps: Int { get {
        return driver?.state.swaps ?? -1
    }}
    var services: [Service] { get {
        return driver?.state.bouquet?.services ?? []
    }}
    var offset: TimeInterval? { get {
        return driver?.state.offset
    }}
    var metadata: AbstractMetadata? { get {
        return driver?.state.metadata
    }}
    
    private var v2Driver:YbridV2Driver? { get {
       return driver as? YbridV2Driver
    }}
    
    init(on endpoint:MediaEndpoint) {
        self.endpoint = endpoint
    }
    
    func connect() throws {
        do {
            let mediaControl = try factory.create(self)
            self.driver = mediaControl
            try mediaControl.connect()
        } catch {
            if let playerError = error as? AudioPlayerError {
                DispatchQueue.global().async {
                    self.playerListener?.error(.fatal, playerError)
                }
                throw error
            } else {
                let playerError = SessionError(.unknown, "cannot connect to endpoint \(endpoint)", error)
                DispatchQueue.global().async {
                    self.playerListener?.error(.fatal, playerError)
                }
                throw playerError
            }
        }
    }
    func close() {
        self.driver?.disconnect()
    }
    
    func refresh() {
        v2Driver?.info()
    }
    
    var changingOver:YbridAudioPlayer.ChangeOver? { didSet {
        Logger.session.debug("change over type \(changingOver?.subInfo.rawValue ?? "(nil)")")
    }}
    
    private func fetchMetadataSync(metadataIn: AbstractMetadata) -> AbstractMetadata {
        guard let media = v2Driver else {
            return metadataIn
        }
        
        if .timeshift == changingOver?.subInfo {
            media.info()
        }
        else {
            if let streamUrl = (metadataIn as? IcyMetadata)?.streamUrl {
                media.showMeta(streamUrl)
            } else {
                media.info()
            }
        }
        return driver?.state.metadata ?? metadataIn
    }

    func notifyMetadata() {
        if driver?.hasChanged(SubInfo.metadata) == true,
           let metadata = metadata {
            DispatchQueue.global().async {
                self.playerListener?.metadataChanged(metadata)
                self.driver?.clearChanged(SubInfo.metadata)
            }
        }
    }
    
    func notifyMetadataSync(_ metadataIn:AbstractMetadata) {
        let metadataOut = fetchMetadataSync(metadataIn: metadataIn)
        DispatchQueue.global().async {
            self.playerListener?.metadataChanged(metadataOut)
            self.driver?.clearChanged(SubInfo.metadata)
        }
    }
    
    func maintainMetadata(metadataIn: AbstractMetadata) -> UUID {
        let metadataOut = fetchMetadataSync(metadataIn: metadataIn)
        let uuid = UUID()
        metadataDict.put(id: uuid, value: metadataOut)
        return uuid
    }

    func notifyMetadata(uuid:UUID) {
        if let metadata = metadataDict.pop(id:uuid) {
            DispatchQueue.global().async {
                self.playerListener?.metadataChanged(metadata)
                self.driver?.clearChanged(SubInfo.metadata)
            }
        }
    }
    
    
    func notifyOffset(complete:Bool = true) {
        if driver?.hasChanged(SubInfo.timeshift) == true,
           let ybridListener = self.playerListener as? YbridControlListener {
            DispatchQueue.global().async {
                ybridListener.offsetToLiveChanged(self.offset)
                if complete { self.driver?.clearChanged(SubInfo.timeshift) }
            }
        }
    }
    
    func notifySwapsLeft() {
        if driver?.hasChanged(SubInfo.playout) == true,
           let ybridListener = self.playerListener as? YbridControlListener {
            DispatchQueue.global().async {
                ybridListener.swapsChanged(self.swaps)
                self.driver?.clearChanged(SubInfo.playout) }
        }
    }
    
    func notifyServices() {
        if driver?.hasChanged(SubInfo.bouquet) == true,
           let ybridListener = self.playerListener as? YbridControlListener {
            DispatchQueue.global().async {
                ybridListener.servicesChanged(self.services)
                self.driver?.clearChanged(SubInfo.bouquet) }
        }
    }
    
    
    func notifyError(_ severity:ErrorSeverity, _ error: SessionError) {
        DispatchQueue.global().async {
            self.playerListener?.error(severity, error)
        }
    }
    
    func wind(by:TimeInterval) -> Bool {
        return v2Driver?.wind(by: by) ?? false
    }
    func windToLive() -> Bool {
        return v2Driver?.windToLive() ?? false
    }
    func wind(to:Date) -> Bool {
        return v2Driver?.wind(to:to) ?? false
    }
    func skipForward(_ type:ItemType?) -> Bool {
        return v2Driver?.skipItem(true, type) ?? false
    }
    func skipBackward(_ type:ItemType?) -> Bool {
        return v2Driver?.skipItem(false, type) ?? false
    }
    
    func swapItem() -> Bool {
        return v2Driver?.swapItem(.end2end) ?? false
    }
    func swapService(id:String) -> Bool {
        return v2Driver?.swapService(id: id) ?? false
    }
}


