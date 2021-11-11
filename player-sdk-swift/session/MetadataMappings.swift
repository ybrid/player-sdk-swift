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
    
    var streamUrl:String?
    
    init(icyData:[String:String]) {
        super.init(current: IcyMetadata.createItem(icyData),
                   service: IcyMetadata.createService(icyData))
        streamUrl = icyData["StreamUrl"]?.trimmingCharacters(in: CharacterSet.init(charactersIn: "'"))
    }
    
    // content of http-headers "icy-name" and "icy-genre" ("ice-*" were mapped to "icy-*")
    public static func createService(_ icy: [String:String]) -> Service? {
        guard let name = icy["icy-name"] else { return nil }
        return Service(identifier: name, displayName: name, genre: icy["icy-genre"])
    }
        
    // content of icy-data "StreamTitle", mostly "[$ARTIST - ]$TITLE"
    private static func createItem(_ icy: [String:String]) -> Item? {
        guard let displayTitle = icy["StreamTitle"]?.trimmingCharacters(in: CharacterSet.init(charactersIn: "'")) else {
            return nil
        }
        
        return Item(type:ItemType.UNKNOWN, displayTitle:displayTitle, identifier:nil, title:nil, artist:nil, album:nil, version:nil, description:nil, playbackLength:nil, genre: nil,
            infoUri: nil, companions: nil)
    }
}

class OpusMetadata : AbstractMetadata {
    init(vorbisComments:[String:String]) {
        super.init(current: OpusMetadata.createItem(vorbis: vorbisComments) )
    }
    
    private static func createItem(vorbis: [String:String]) -> Item? {
        let displayTitle = OpusMetadata.combinedTitle(comments: vorbis)
        return Item(type:ItemType.UNKNOWN, displayTitle:displayTitle, identifier:nil, title:vorbis["TITLE"], artist:vorbis["ARTIST"], album:vorbis["ALBUM"], version:vorbis["VERSION"], description:nil, playbackLength:nil, genre: nil,
                    infoUri: nil, companions: nil)
    }
    
    // returns "[$ALBUM - ][$ARTIST - ]$TITLE[ ($VERSION)]"
    private static func combinedTitle(comments: [String:String]) -> String {
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
        return result
    }
}

class YbridMetadata : AbstractMetadata {
    
    init(ybridV2:YbridV2Metadata) {
        super.init(current: YbridMetadata.createItem(ybrid: ybridV2.currentItem),
                   next: YbridMetadata.createItem(ybrid: ybridV2.nextItem),
                   service: YbridMetadata.createService(ybridV2.station) )
    }

    // content of __responseObject.metatdata.station
    private static func createService(_ ybridStation: YbridStation) -> Service? {
        let name = ybridStation.name
        return Service(identifier: name, displayName: name, genre: ybridStation.genre)
    }
    
    private static func createItem(ybrid: YbridItem) -> Item? {
        let type = YbridMetadata.typeFrom(type: ybrid.type)
        let displayTitle = YbridMetadata.combinedTitle(item: ybrid)
        let playbackLength = TimeInterval( ybrid.durationMillis / 1_000 )
        return Item(type:type, displayTitle:displayTitle, identifier:ybrid.id, title:ybrid.title, artist:ybrid.artist, album:nil, version:nil, description:ybrid.description, playbackLength: playbackLength, genre: nil,
                    infoUri: nil, companions: nil)
    }
    
    private static func typeFrom(type: String) -> ItemType {
        if let type = ItemType(rawValue: type) {
            return type
        }
        return ItemType.UNKNOWN
    }
    
    // returns "$TITLE[ by $ARTIST]"
    private static func combinedTitle(item: YbridItem) -> String {
        var result = item.title
        if !item.artist.isEmpty {
            result += "\nby \(item.artist)"
        }
        return result
    }
    
    
}

