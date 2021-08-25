//
// State.swift
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

class MediaState  {
    
    let endpointUri:URL
    var baseUrl:URL
    var playbackUri:String
    var token:String?

    var startDate:Date? { didSet {
        if let start = startDate, startDate != oldValue {
            Logger.session.debug("start date is \(Formatter.iso8601withMillis.string(from: start))")
        }
    }}
    
    var metadata:AbstractMetadata? { didSet {
        if let _ = metadata {
            setChanged(SubInfo.metadata)
        }
    }}
    
    var bouquet:Bouquet? { didSet {
        if let services = bouquet?.services, services != oldValue?.services {
            setChanged(SubInfo.bouquet)
        }
        if let active = bouquet?.activeService, active != oldValue?.activeService {
            setChanged(SubInfo.bouquet)
        }
    }}
    
    var swaps:Int? = nil { didSet {
        if oldValue != swaps {
            setChanged(SubInfo.playout)
        }
    }}
    
    var maxBitRate:Int32? {
        didSet {
            if let bitrate = maxBitRate, bitrate != oldValue {
                setChanged(SubInfo.playout)
            }
        }
    }
    
    var currentBitRate:Int32? {
        didSet {
            if let bitrate = currentBitRate, bitrate != oldValue {
                setChanged(SubInfo.playout)
            }
        }
    }
    
    var offset:TimeInterval? { didSet {
        if let _ = offset {
            setChanged(SubInfo.timeshift)
        }
    }}

    
    private let changed = ThreadsafeSet<SubInfo>(MediaState.stateQueue)
    static let stateQueue = DispatchQueue(label: "io.ybrid.session.state.changes")
    
    init(_ endpoint:MediaEndpoint) {
        self.endpointUri = URL(string: endpoint.uri)!
        self.playbackUri = endpoint.uri
        self.baseUrl = endpointUri
    }

 
    func clearChanged(_ what:SubInfo) {
        changed.remove(what)
    }
    private func setChanged(_ what: SubInfo) {
        changed.insert(what)
    }
    func hasChanged(_ what: SubInfo) -> Bool {
        return changed.contains(what);
    }
    

 
 
}
