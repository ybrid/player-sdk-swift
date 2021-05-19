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
    
    var offsetToLiveS:TimeInterval? { get {
        return (mediaControl as? YbridV2Driver)?.offsetToLiveS
    }}
        
    weak var ybridListener:YbridControlListener? { didSet {
        if let v2Control = mediaControl as? YbridV2Driver {
            v2Control.listener = ybridListener
        }
    }}
    
    public var mediaProtocol:MediaProtocol? { get {
        return mediaControl?.mediaProtocol
    }}

    public var playbackUri:String { get {
        return mediaControl?.playbackUri ?? endpoint.uri
    }}
    
    var metadataDict = ThreadsafeDictionary<UUID,AbstractMetadata>(
        DispatchQueue(label: "io.ybrid.metadata.maintaining", qos: PlayerContext.processingPriority)
    )
    
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
    
    func fetchMetadataSync() -> AbstractMetadata? {
        if let v2Control = (mediaControl as? YbridV2Driver) {
            v2Control.info()
            if let ybridData = v2Control.ybridMetadata {
                return YbridMetadata(ybridV2: ybridData)
            }
        }
        return nil
    }
    
    func maintainMetadata(metadata: AbstractMetadata) -> UUID {
        if let v2Control = (mediaControl as? YbridV2Driver) {
            v2Control.info()
            if let ybridData = v2Control.ybridMetadata {
                let ybridMetadata = YbridMetadata(ybridV2: ybridData)
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
    
}


