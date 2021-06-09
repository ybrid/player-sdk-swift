//
// Metadata.swift
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

// Metadata contains data corresponding to a time period or a single instance of a stream.
// The data can origin from different sources. In general it is up to the purpose
// which of the data is relevant.

import Foundation

public enum SubInfo {
    case metadata
    case bouquet
//    case PLAYOUT
//    case CAPABILITIES
//    case VALIDITY
}

public protocol Metadata {
    // fixed syntax containing TITLE and if available ARTIST
    // ALBUM (and version) if available in vorbis comments
    var displayTitle: String? { get }
    
    var station: Station? { get }
    var current: Item? { get }
    var next: Item? { get }
    
    var activeService: Service? { get }
}

public struct Item {
    public let type: ItemType
    public let displayTitle: String
    
    public let identifier: String?
    public let title: String?
    public let version: String?
    public let artist: String?
    public let album: String?
    public let description: String?
    public let durationMillis: Int64?
}

public enum ItemType : String  {
    case ADVERTISEMENT = "ADVERTISEMENT"
    case COMEDY = "COMEDY"
    case JINGLE = "JINGLE"
    case MUSIC = "MUSIC"
    case NEWS = "NEWS"
    case TRAFFIC = "TRAFFIC"
    case VOICE = "VOICE"
    case WEATHER = "WEATHER"
    case UNKNOWN
}

public struct Station {
    public var name: String?
    public var genre: String?
}

public struct Service {
    public let identifier:String
    public var displayName:String?
    public var iconUri:String?
}

class AbstractMetadata : Metadata {
    
    private var currentItem:Item?
    private var nextItem:Item?
    private var stationInfo: Station?
    private var delegate:AbstractMetadata?
    
    init(current:Item? = nil, next:Item? = nil, station:Station? = nil) {
        self.currentItem = current
        self.nextItem = next
        self.stationInfo = station
    }
    
    func delegate(with other: AbstractMetadata) {
        self.delegate = other
    }
    
    func setBroadcaster(_ broadcaster:String) {
        guard let _ = stationInfo else {
            stationInfo = Station(name:broadcaster)
            return
        }
        stationInfo!.name = broadcaster
    }
    
    func setGenre(_ genre:String) {
        guard let _ = stationInfo else {
            stationInfo = Station(genre:genre)
            return
        }
        stationInfo!.genre = genre
    }
    
    public final var displayTitle: String? {
        if let delegate = delegate {
            return delegate.displayTitle
        }
        return current?.displayTitle
    }
    
    public final var station: Station?  {
        if let delegate = delegate {
            return delegate.station
        }
        return stationInfo
    }
    
    public final var current: Item? {
        if let delegate = delegate {
            return delegate.current
        }
        return currentItem
    }
    
    public final var next: Item?  {
        if let delegate = delegate {
            return delegate.next
        }
        return nextItem
    }
    
    public final var activeService: Service? {
        if let delegate = delegate {
            return delegate.activeService
        }
        guard let ybrid = self as? YbridMetadata else {
            return nil
        }
        return ybrid.currentService
    }
    
}

