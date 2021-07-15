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

protocol MediaControl {
    var playbackUri: String { get }
    var connected: Bool { get }
    var mediaProtocol: MediaProtocol { get }
    func hasChanged(_ what: SubInfo) -> Bool
//    func clearChanged(_ what: SubInfo)
}

enum SubInfo {
    case metadata
    case bouquet
    case playout
//    case CAPABILITIES
//    case VALIDITY
}

class MediaDriver : MediaControl {
    
    let mediaProtocol:MediaProtocol
    var endpointUri:URL
    var baseUrl:URL
    var playbackUri:String
    var valid:Bool = true //  { get }
    var connected:Bool = false { didSet {
        Logger.session.info("\(mediaProtocol) controller \(connected ? "connected" : "disconnected")")
    }}
    
    var bouquet:Bouquet? { didSet {
        if let services = bouquet?.services, services != oldValue?.services {
            changed.insert(SubInfo.bouquet)
            DispatchQueue.global().async {
                self.listener?.servicesChanged(services)
                self.changed.remove(SubInfo.bouquet)
            }
        }
    }}
    
    var metadata:AbstractMetadata? { didSet {
        changed.insert(SubInfo.metadata)
    }}
    
    var swaps:Int? { didSet {
        if let swaps = swaps {
            DispatchQueue.global().async {
                self.listener?.swapsChanged(swaps)
            }
        }
    }}
    
    var offset:TimeInterval? { didSet {
        if oldValue != offset {
            changed.insert(SubInfo.playout)
        }
    }}
    
    let changed = ThreadsafeSet<SubInfo>(MediaDriver.v2Queue)
    static let v2Queue = DispatchQueue(label: "io.ybrid.session.driver.changes")
    
    private weak var listener:YbridControlListener?
    
    init(session:MediaSession, version:MediaProtocol) {
        self.mediaProtocol = version
        self.playbackUri = session.endpoint.uri
        self.endpointUri = URL(string: session.endpoint.uri)!
        self.baseUrl = endpointUri
        self.listener = session.playerListener as? YbridControlListener
    }
    
    func connect() throws {}
    func disconnect() {}
    //    var playoutInfo: PlayoutInfo { get }
    //    var capabilities: CapabilitySet { get }
    
    func clearChanged(_ what: SubInfo) {
        changed.remove(what)
    }
    func hasChanged(_ what: SubInfo) -> Bool {
        return changed.contains(what)
    }
    
    //    func getBouquet() -> Bouquet
    //    @NotNull Service getCurrentService();
    
    func notify(_ severity:ErrorSeverity, _ error: SessionError ) {
        DispatchQueue.global().async {
            self.listener?.error(severity, error)
        }
    }
}
