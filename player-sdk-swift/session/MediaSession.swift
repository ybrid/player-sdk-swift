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
     
    weak var ybridListener:YbridControlListener? { didSet {
        mediaControl?.listener = ybridListener
    }}
    
    public var mediaProtocol:MediaProtocol? { get {
        return mediaControl?.mediaProtocol
    }}

    public var playbackUri:String { get {
        return mediaControl?.playbackUri ?? endpoint.uri
    }}
    
    private var metadataDict = ThreadsafeDictionary<UUID,AbstractMetadata>(
        DispatchQueue(label: "io.ybrid.metadata.maintaining", qos: PlayerContext.processingPriority)
    )
     
    private var v2Driver:YbridV2Driver? { get {
        return mediaControl as? YbridV2Driver
    }}
    
    var swapsLeft: Int? { get {
        return v2Driver?.swapsLeft
    }}
    var services: [Service]? { get {
        return mediaControl?.bouquet?.services
    }}
    var offsetToLiveS: TimeInterval? { get {
        return v2Driver?.offsetToLiveS
    }}
    
    init(on endpoint:MediaEndpoint) {
        self.endpoint = endpoint
    }
    
    func connect() throws {
        let mediaControl = try factory.create(self)
        self.mediaControl = mediaControl
        try mediaControl.connect()
    }
    func close() {
        self.mediaControl?.disconnect()
    }
    
    func refresh() {
        if let media = v2Driver {
            media.info()
        }
    }
     
    func fetchMetadataSync() -> AbstractMetadata? {
        if let media = v2Driver {
            media.info()
            if let ybridData = media.ybridMetadata {
                let metadata = YbridMetadata(ybridV2: ybridData)
                metadata.currentService = mediaControl?.bouquet?.activeService
                return metadata
            }
        }
        return nil
    }
    func maintainMetadata(metadata: AbstractMetadata) -> UUID {
        if let media = v2Driver {
            media.info()
            if let ybridData = media.ybridMetadata {
                let ybridMetadata = YbridMetadata(ybridV2: ybridData)
                ybridMetadata.currentService = mediaControl?.bouquet?.activeService
                metadata.delegate(with: ybridMetadata)
            }
        }
        let uuid = UUID()
        metadataDict.put(id: uuid, value: metadata)
        return uuid
    }
    func popMetadata(uuid:UUID) -> AbstractMetadata? {
        return metadataDict.pop(id:uuid)
    }
    
    func wind(by:TimeInterval) {
        v2Driver?.wind(by: by)
    }
    func windToLive() -> Bool {
        return v2Driver?.windToLive() ?? false
    }
    func wind(to:Date) {
        v2Driver?.wind(to:to)
    }
    func skipForward(_ type:ItemType?) {
        v2Driver?.skipItem(true, type)
    }
    func skipBackward(_ type:ItemType?) {
        v2Driver?.skipItem(false, type)
    }
    
    func swapItem() -> Bool {
        return v2Driver?.swapItem(.end2end) ?? false
    }
    func swapService(id:String) -> Bool {
        return v2Driver?.swapService(id: id) ?? false
    }
}


