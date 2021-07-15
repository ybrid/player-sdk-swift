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
    var mediaControl:MediaDriver?
     
    weak var playerListener:AudioPlayerListener?
    
    public var mediaProtocol:MediaProtocol? { get {
        return mediaControl?.mediaProtocol
    }}

    public var playbackUri:String { get {
        return mediaControl?.playbackUri ?? endpoint.uri
    }}
    
    private var metadataDict = ThreadsafeDictionary<UUID,AbstractMetadata>(
        DispatchQueue(label: "io.ybrid.metadata.maintaining", qos: PlayerContext.processingPriority)
    )
    
    var swaps: Int? { get {
        return mediaControl?.swaps
    }}
    var services: [Service]? { get {
        return mediaControl?.bouquet?.services
    }}
    var offset: TimeInterval? { get {
        return mediaControl?.offset
    }}
    var metadata: AbstractMetadata? { get {
        return mediaControl?.metadata
    }}
    
    private var v2Driver:YbridV2Driver? { get {
       return mediaControl as? YbridV2Driver
    }}
    
    init(on endpoint:MediaEndpoint) {
        self.endpoint = endpoint
    }
    
    func connect() throws {
        do {
            let mediaControl = try factory.create(self)
            self.mediaControl = mediaControl
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
        self.mediaControl?.disconnect()
    }
    
    func refresh() {
        v2Driver?.info()
    }
    
    func notifyMetadata() {
        if let metadata = metadata {
            DispatchQueue.global().async {
                self.playerListener?.metadataChanged(metadata)
            }
        }
    }
    
    func notifyMetadataSync(_ metadataIn:AbstractMetadata) {
        let metadataOut = fetchMetadataSync(metadataIn: metadataIn)
        DispatchQueue.global().async {
            self.playerListener?.metadataChanged(metadataOut)
            self.mediaControl?.clearChanged(SubInfo.metadata)
        }
    }
    
    func maintainMetadata(metadataIn: AbstractMetadata) -> UUID {
        let metadataOut = fetchMetadataSync(metadataIn: metadataIn)
        self.mediaControl?.clearChanged(SubInfo.metadata)
        let uuid = UUID()
        metadataDict.put(id: uuid, value: metadataOut)
        return uuid
    }

    func notifyMetadata(uuid:UUID) {
        if let metadata = metadataDict.pop(id:uuid) {
            DispatchQueue.global().async {
                self.playerListener?.metadataChanged(metadata)
            }
        }
    }
    
    private func fetchMetadataSync(metadataIn: AbstractMetadata) -> AbstractMetadata {
        if let media = v2Driver {
            if let streamUrl = (metadataIn as? IcyMetadata)?.streamUrl {
                media.showMeta(streamUrl)
            } else {
                media.info()
            }
            return mediaControl?.metadata ?? metadataIn
        }
        return metadataIn
    }
    
    func notifyOffset(complete:Bool) {
        if mediaControl?.hasChanged(SubInfo.playout) == true,
           let ybridListener = self.playerListener as? YbridControlListener {
            DispatchQueue.global().async {
                ybridListener.offsetToLiveChanged(self.offset)
                if complete { self.mediaControl?.clearChanged(SubInfo.playout) }
            }
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


