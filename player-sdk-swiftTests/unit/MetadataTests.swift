//
// MetadataTests.swift
// player-sdk-swiftTests
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

import XCTest

class MetadataTests: XCTestCase {

    // ybrid examples
    let heyJudeYbridItem = YbridItem(id: "anyId", artist: "Beatles", title: "Hey Jude", description: "test song", durationMillis: 238000, companions: [], type: "MUSIC")
    let noTitleYbridItem = YbridItem(id: "otherId", artist: "", title: "", description: "", durationMillis: 0, companions: [], type: "")
    let ybridDemoYbridStation = YbridStation(genre: "", name: "")
    let newsYbridItem = YbridItem(id: "newsId", artist: "", title: "Nachrichten", description: "what happened tody", durationMillis: 238000, companions: [], type: "NEWS")
    let metadataRawJson = "{\"station\":{\"genre\":\"\",\"name\":\"\"},\"nextItem\":{\"artist\":\"Ybrid® Hybrid Dynamic Live Audio Technology\",\"id\":\"384\",\"durationMillis\":9912,\"title\":\"Your Personal Audio Experience\",\"companions\":[],\"type\":\"JINGLE\",\"description\":\"\"},\"currentItem\":{\"artist\":\"Air\",\"id\":\"383\",\"durationMillis\":268416,\"title\":\"All I Need\",\"companions\":[],\"type\":\"MUSIC\",\"description\":\"\"}}"
    
    func toYbridV2Metadata(_ inString:String) -> YbridV2Metadata {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(Formatter.iso8601withMilliSeconds)
        let metadata:YbridV2Metadata = try! decoder.decode(YbridV2Metadata.self, from: inString.data(using: .utf8)! )
            return metadata
    }

    // icy examples
    let heyJudeIcyTitle = ["StreamTitle":"Beatles - Hey Jude"]
    
    // vorbis commands examples
    let heyJudeWrongVorbisComments = ["title":"Hey Jude", "artist":"Beatles"]
    let heyJudeVorbisComments = ["TITLE":"Hey Jude", "ARTIST":"Beatles"]
    let heyJudeFullVorbisComments = ["TITLE":"Hey Jude", "ARTIST":"Beatles",
                                     "ALBUM":"Love", "VERSION":"Remastered 2015"]
    
    
    func testDisplayTitle_IcyOnly() {
        let metadata = IcyMetadata(icyData: heyJudeIcyTitle)
        XCTAssertEqual("Beatles - Hey Jude", metadata.displayTitle )
    }

    func testDisplayTitle_VorbisCommandsAreCaseSensitive() {
        let metadata = OpusMetadata(vorbisComments: heyJudeWrongVorbisComments)
        XCTAssertEqual("", metadata.displayTitle )
    }
    
    func testDisplayTitle_OpusOnly() {
        let metadata = OpusMetadata(vorbisComments: heyJudeVorbisComments)
        XCTAssertEqual("Beatles - Hey Jude", metadata.displayTitle )
    }
    
    func testDisplayTitle_OpusMaxSyntax() {
        let metadata = OpusMetadata(vorbisComments: heyJudeFullVorbisComments )
        XCTAssertEqual("Love - Beatles - Hey Jude (Remastered 2015)", metadata.displayTitle )
    }
    
    func testDisplayTitle_ybridOnly() {
        let ybridMD = YbridV2Metadata(currentItem: heyJudeYbridItem, nextItem: noTitleYbridItem, station: ybridDemoYbridStation)
        let metadata = YbridMetadata(ybridV2: ybridMD)
        XCTAssertEqual("Hey Jude\nby Beatles", metadata.displayTitle )
    }

    func testDisplayTitle_icyAndYbrid_YbridWins() {
        let metadata = IcyMetadata(icyData: heyJudeIcyTitle )
        let ybridMD = YbridV2Metadata(currentItem: heyJudeYbridItem, nextItem: noTitleYbridItem, station: ybridDemoYbridStation)
        metadata.delegate(with: YbridMetadata(ybridV2: ybridMD))
        XCTAssertEqual("Hey Jude\nby Beatles", metadata.displayTitle )
    }
    
    func testDisplayTitle_OpusAndYbrid_YbridWins() {
        let metadata = OpusMetadata(vorbisComments: heyJudeVorbisComments )
        let ybridMD = YbridV2Metadata(currentItem: heyJudeYbridItem, nextItem: noTitleYbridItem, station: ybridDemoYbridStation)
        metadata.delegate(with: YbridMetadata(ybridV2: ybridMD))
        XCTAssertEqual("Hey Jude\nby Beatles", metadata.displayTitle )
    }
    
    
    func testDisplayTitle_YbridAndYbrid_DelegateWins() {
        let ybridMD = YbridV2Metadata(currentItem: heyJudeYbridItem, nextItem: noTitleYbridItem, station: ybridDemoYbridStation)
        let metadata = YbridMetadata(ybridV2: ybridMD)
        
        let md = toYbridV2Metadata(metadataRawJson)
        let metadata2 = YbridMetadata(ybridV2: md)
        metadata.delegate(with: metadata2)
        
        XCTAssertEqual("All I Need\nby Air",  metadata.displayTitle)
        XCTAssertEqual("All I Need",  metadata.current?.title )
        XCTAssertEqual(ItemType.JINGLE,  metadata.next?.type )
        
    }
    
    func testYbridMetadata_CurrentNextStation() {
        let md = toYbridV2Metadata(metadataRawJson)
        let metadata = YbridMetadata(ybridV2: md)
        
        XCTAssertEqual(ItemType.MUSIC, metadata.current?.type )
        XCTAssertEqual("Air", metadata.current?.artist )
        
        XCTAssertEqual(ItemType.JINGLE, metadata.next?.type )
        XCTAssertEqual("Your Personal Audio Experience", metadata.next?.title )
    }

}
