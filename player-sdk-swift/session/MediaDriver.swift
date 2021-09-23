//
// Controller.swift
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

enum SubInfo : String, CaseIterable {
    case metadata
    case timeshift
    case bouquet
    case playout
//    case CAPABILITIES
//    case VALIDITY
}

protocol MediaSessionDelegate {
//    func fetchMetadataSync(metadataIn: AbstractMetadata)
    func disconnect()
    var state:MediaState { get }
    var mediaProtocol:MediaProtocol { get }
    func clearChanged(_ what: SubInfo)
    func hasChanged(_ what: SubInfo) -> Bool 
}

class MediaDriver : MediaSessionDelegate {
    
    let mediaProtocol:MediaProtocol
    var valid:Bool = true //  { get }
    var connected:Bool = false { didSet {
        Logger.session.info("\(mediaProtocol) controller \(connected ? "connected" : "disconnected")")
    }}
    var state:MediaState
    
//    let changed = ThreadsafeSet<SubInfo>(MediaDriver.v2Queue)
//    static let v2Queue = DispatchQueue(label: "io.ybrid.session.driver.changes")
//    
    private weak var listener:AudioPlayerListener?
    
    init(session:MediaSession, version:MediaProtocol) {
        self.mediaProtocol = version
        self.listener = session.playerListener
        self.state = MediaState(session.endpoint)
    }
    
    func connect() throws {}
    func disconnect() {}
    //    var playoutInfo: PlayoutInfo { get }
    //    var capabilities: CapabilitySet { get }
    
    func clearChanged(_ what: SubInfo) {
        state.clearChanged(what)
    }
    func hasChanged(_ what: SubInfo) -> Bool {
        return state.hasChanged(what)
    }
    
    func fetchMetadataSync(metadataIn: AbstractMetadata) {
        fatalError(#function + " must be overridden")
    }
    //    func getBouquet() -> Bouquet
    //    @NotNull Service getCurrentService();
    

}
