//
// MetadataMappings.swift
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


class IcyMetadata : AbstractMetadata {
    
    private let data:[String:String]
    override var description:String { get {
        return "\(type(of: self)) with keys \(data.keys)"
    }}
    
    init(icyData:[String:String]) {
        self.data = icyData
        super.init()
    }
    
    override var streamUrl:String? { get {
        return super.delegate?.streamUrl ??
            data["StreamUrl"]?.trimmingCharacters(in: CharacterSet.init(charactersIn: "'"))
    }}

    // content of icy-data "StreamTitle", mostly "[$ARTIST - ]$TITLE"
    override var currentInfo: Item? { get {
        guard let displayTitle = data["StreamTitle"]?.trimmingCharacters(in: CharacterSet.init(charactersIn: "'")) else {
            return nil
        }
        
        return Item(displayTitle:displayTitle)
    }}
    
    // content of http-headers "icy-name" and "icy-genre" ("ice-*" were mapped to "icy-*")
    override var serviceInfo: Service? { get {
        guard let name = data["icy-name"] else { return nil }
        return Service(identifier: name, displayName: name, genre: data["icy-genre"],
                       description: data["icy-description"], infoUri: data["icy-url"] )
    }}
}


class OpusMetadata : AbstractMetadata {
    private let vorbis:[String:String]
    override var description:String { get {
        return "\(type(of: self)) with vorbis comments \(vorbis.keys)"
    }}
    init(vorbisComments:[String:String]) {
        self.vorbis = vorbisComments
        super.init()
    }
    
    override var currentInfo: Item? { get {
        let displayTitle = combinedTitle(comments: vorbis) ?? ""
//        guard let displayTitle = combinedTitle(comments: vorbis) else {
//            return nil
//        }
        return Item(displayTitle:displayTitle, title:vorbis["TITLE"], artist:vorbis["ARTIST"],
                    album:vorbis["ALBUM"], version:vorbis["VERSION"],
                    description:vorbis["DESCRIPTION"], genre:vorbis["GENRE"])
    }}
    
    // returns "[$ALBUM - ][$ARTIST - ]$TITLE[ ($VERSION)]"
    private func combinedTitle(comments: [String:String]) -> String? {
        let relevant:[String] = ["ALBUM", "ARTIST", "TITLE"]
        let playout = relevant
            .filter { comments[$0] != nil }
            .map { comments[$0]! }
        var result = playout.joined(separator: " - ")
        if let version = comments["VERSION"] {
            result += " (\(version))"
        }
        if result.count > 0 {
            return result
        }
        return nil
    }
}


class YbridMetadata : AbstractMetadata {
    let v2:YbridV2Metadata
    init(ybridV2:YbridV2Metadata) {
        self.v2 = ybridV2
        super.init()
    }

    override var currentInfo: Item? { get {
        return createItem(ybrid: v2.currentItem)
    }}
    
    override var nextInfo: Item? { get {
        return createItem(ybrid: v2.nextItem)
    }}
    
    override var serviceInfo: Service? { get {
        // content of __responseObject.metatdata.station
        let ybridStation = v2.station
        let name = ybridStation.name
        return Service(identifier: name, displayName: name, genre: ybridStation.genre)
    }}
    
    private func createItem(ybrid: YbridItem) -> Item? {
        let type = typeFrom(type: ybrid.type)
        let displayTitle = combinedTitle(item: ybrid)
        let playbackLength = TimeInterval( ybrid.durationMillis / 1_000 )
        return Item(displayTitle:displayTitle, identifier:ybrid.id, type:type,
                    title:ybrid.title, artist:ybrid.artist,
                    description:ybrid.description, playbackLength: playbackLength)
    }
    
    private func typeFrom(type: String) -> ItemType {
        if let type = ItemType(rawValue: type) {
            return type
        }
        return ItemType.UNKNOWN
    }
    
    // returns "$TITLE[ by $ARTIST]"
    private func combinedTitle(item: YbridItem) -> String {
        var result = item.title
        if !item.artist.isEmpty {
            result += "\nby \(item.artist)"
        }
        return result
    }
}
