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
@testable import YbridPlayerSDK

class MetadataTests: XCTestCase {

    // ybrid examples
    let heyJudeYbridItem = YbridItem(id: "anyId", artist: "Beatles", title: "Hey Jude", description: "test song", durationMillis: 238000, type: "MUSIC")
    let noTitleYbridItem = YbridItem(id: "otherId", artist: "", title: "", description: "", durationMillis: 0, type: "")
    let ybridDemoYbridStation = YbridStation(genre: "", name: "Ybrid demo")
    let newsYbridItem = YbridItem(id: "newsId", artist: "", title: "Nachrichten", description: "what happened tody", durationMillis: 238000, type: "NEWS")
    let metadataRawJson = "{\"station\":{\"genre\":\"\",\"name\":\"\"},\"nextItem\":{\"artist\":\"Ybrid® Hybrid Dynamic Live Audio Technology\",\"id\":\"384\",\"durationMillis\":9912,\"title\":\"Your Personal Audio Experience\",\"companions\":[],\"type\":\"JINGLE\",\"description\":\"\"},\"currentItem\":{\"artist\":\"Air\",\"id\":\"383\",\"durationMillis\":268416,\"title\":\"All I Need\",\"companions\":[],\"type\":\"MUSIC\",\"description\":\"\"}}"
    
    func toYbridV2Metadata(_ inString:String) -> YbridV2Metadata {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(Formatter.iso8601withMillis)
        let metadata:YbridV2Metadata = try! decoder.decode(YbridV2Metadata.self, from: inString.data(using: .utf8)! )
            return metadata
    }

    // icy examples
    let heyJudeIcyTitle = ["StreamTitle":"Beatles - Hey Jude"]
    let swr3IcyName = ["icy-name":"SWR3","icy-genre":"Pop Music"]
    let hr2IcyRawHeaders = ["icy-metaint": "16000", "icy-pub": "0", "icy-name": "hr2", "icy-url": "http://www.hr.de"]
    let swr3IcyYbridDemoRawOccurs = ["icy-pub": "1", "icy-metaint": "1024"]
 
    
    // vorbis commands examples
    let heyJudeWrongVorbisComments = ["title":"Hey Jude", "artist":"Beatles"]
    let heyJudeVorbisComments = ["TITLE":"Hey Jude", "ARTIST":"Beatles"]
    let heyJudeFullVorbisComments = ["TITLE":"Hey Jude", "ARTIST":"Beatles",
                                     "ALBUM":"Love", "VERSION":"Remastered 2015"]
    
    
    func testIcyOnly_Title() {
        let metadata = IcyMetadata(icyData: heyJudeIcyTitle)
        XCTAssertEqual("Beatles - Hey Jude", metadata.displayTitle )
        XCTAssertEqual("default", metadata.service.identifier )
    }
    
    func testIcyOnly_Service() {
        let metadata = IcyMetadata(icyData: hr2IcyRawHeaders)
        XCTAssertEqual("", metadata.displayTitle )
        XCTAssertEqual("hr2", metadata.service.identifier )
        XCTAssertEqual("hr2", metadata.service.displayName )
    }
    
    func testVobisCommentsOnly_Title() {
        let metadata = OpusMetadata(vorbisComments: heyJudeVorbisComments)
        XCTAssertEqual("Beatles - Hey Jude", metadata.displayTitle )
        XCTAssertEqual("default", metadata.service.identifier )
    }
    
    func testVorbisCommands_AreCaseSensitive() {
        let metadata = OpusMetadata(vorbisComments: heyJudeWrongVorbisComments)
        XCTAssertEqual("", metadata.displayTitle )
    }
    
    func testVorbisCommands_TitleMaxSyntax() {
        let metadata = OpusMetadata(vorbisComments: heyJudeFullVorbisComments )
        XCTAssertEqual("Love - Beatles - Hey Jude (Remastered 2015)", metadata.displayTitle )
    }
    
     func testYbrid_TitleCurrentNextService() {
        let md = toYbridV2Metadata(metadataRawJson)
        let metadata = YbridMetadata(ybridV2: md)
        
        XCTAssertEqual("All I Need\nby Air", metadata.displayTitle )
        
        XCTAssertEqual(ItemType.MUSIC, metadata.current.type )
        XCTAssertEqual("Air", metadata.current.artist )
        
        XCTAssertEqual(ItemType.JINGLE, metadata.next?.type )
        XCTAssertEqual("Your Personal Audio Experience", metadata.next?.title )
        XCTAssertEqual("Your Personal Audio Experience\nby Ybrid® Hybrid Dynamic Live Audio Technology", metadata.next?.displayTitle )
        
        XCTAssertEqual("", metadata.service.identifier )
        XCTAssertEqual("", metadata.service.displayName )
        XCTAssertEqual("", metadata.service.genre )
    }
    
    // MARK: two objects
    
    func testIcyServiceAndTitle_Merges() {
        let metadata = IcyMetadata(icyData: hr2IcyRawHeaders)
        let icyTitle = IcyMetadata(icyData: heyJudeIcyTitle )
        metadata.delegate(to: icyTitle)
        XCTAssertEqual("Beatles - Hey Jude", metadata.displayTitle )
        XCTAssertEqual("hr2", metadata.service.identifier )
    }
    
    func testIcyAndYbridServices_YbridWinsService() {
        let metadata = IcyMetadata(icyData: hr2IcyRawHeaders )
        XCTAssertEqual("hr2", metadata.service.identifier )
        XCTAssertEqual("hr2", metadata.service.displayName )
        XCTAssertNil(metadata.service.genre )
        
        let ybridMD = YbridV2Metadata(currentItem: heyJudeYbridItem, nextItem: noTitleYbridItem, station: ybridDemoYbridStation)
        metadata.delegate(to: YbridMetadata(ybridV2: ybridMD))
        XCTAssertEqual("Ybrid demo", metadata.service.identifier )
    }
    
    func testIcyAndYbridTitle_YbridWinsTitle() {
        let metadata = IcyMetadata(icyData: heyJudeIcyTitle )
        let ybridMD = YbridV2Metadata(currentItem: heyJudeYbridItem, nextItem: noTitleYbridItem, station: ybridDemoYbridStation)
        metadata.delegate(to: YbridMetadata(ybridV2: ybridMD))
        XCTAssertEqual("Hey Jude\nby Beatles", metadata.displayTitle )
    }
    
    func testIcyAndYbrid_YbridNext() {
        let metadata = IcyMetadata(icyData: hr2IcyRawHeaders )
        
        XCTAssertEqual("hr2", metadata.service.identifier )
        XCTAssertEqual("hr2", metadata.service.displayName )
        XCTAssertNil(metadata.service.genre )
        XCTAssertNil(metadata.next)
        
        
        let ybridMD = YbridV2Metadata(currentItem: noTitleYbridItem, nextItem:heyJudeYbridItem , station: ybridDemoYbridStation)
        metadata.delegate(to: YbridMetadata(ybridV2: ybridMD))
        
        XCTAssertEqual("", metadata.displayTitle )
        
        XCTAssertEqual("Ybrid demo", metadata.service.identifier )
        XCTAssertEqual("Ybrid demo", metadata.service.displayName)
        XCTAssertEqual("", metadata.service.genre)
        
        XCTAssertNotNil(metadata.next)
        XCTAssertEqual("Hey Jude\nby Beatles", metadata.next?.displayTitle )
    }
    
    func testYbridAndYbrid_DelegateWins() {
        let ybridMD = YbridV2Metadata(currentItem: heyJudeYbridItem, nextItem: noTitleYbridItem, station: ybridDemoYbridStation)
        let metadata = YbridMetadata(ybridV2: ybridMD)
        XCTAssertEqual("Hey Jude\nby Beatles", metadata.displayTitle )
        XCTAssertEqual("Ybrid demo",  metadata.service.displayName )
        
        let ybridMD2 = toYbridV2Metadata(metadataRawJson)
        let metadata2 = YbridMetadata(ybridV2: ybridMD2)
        metadata.delegate(to: metadata2)
        
        XCTAssertEqual("All I Need\nby Air",  metadata.displayTitle)
        XCTAssertEqual("All I Need",  metadata.current.title )
        XCTAssertEqual(ItemType.JINGLE,  metadata.next?.type )
        
        XCTAssertEqual("",  metadata.service.identifier )
    }
    
    func testOpusAndYbrid_YbridWins() {
        let metadata = OpusMetadata(vorbisComments: heyJudeVorbisComments )
        let ybridMD = YbridV2Metadata(currentItem: heyJudeYbridItem, nextItem: noTitleYbridItem, station: ybridDemoYbridStation)
        metadata.delegate(to: YbridMetadata(ybridV2: ybridMD))
        XCTAssertEqual("Hey Jude\nby Beatles", metadata.displayTitle )
        XCTAssertEqual("Ybrid demo", metadata.service.identifier )
    }
    
    func testIcyServiceAndOpusTitle_Merges() {
        let metadata = IcyMetadata(icyData: swr3IcyName )
        
        XCTAssertEqual("", metadata.displayTitle)
        
        XCTAssertEqual("SWR3", metadata.service.identifier )
        XCTAssertEqual("SWR3", metadata.service.displayName )
        XCTAssertEqual("Pop Music", metadata.service.genre )

        
        let opusMD = OpusMetadata(vorbisComments: heyJudeFullVorbisComments )
        metadata.delegate(to: opusMD)
        XCTAssertEqual("Love - Beatles - Hey Jude (Remastered 2015)", metadata.displayTitle )
        
        XCTAssertEqual("SWR3", metadata.service.identifier )
        XCTAssertEqual("SWR3", metadata.service.displayName )
        XCTAssertEqual("Pop Music", metadata.service.genre )
    }
    
    func testIcyAndIcyService_DelegateWins() {

        let metadata = IcyMetadata(icyData: swr3IcyName )
        let md2 = IcyMetadata(icyData: hr2IcyRawHeaders )
        metadata.delegate(to: md2)
        
        XCTAssertEqual("hr2", metadata.service.identifier )
        XCTAssertEqual("hr2", metadata.service.displayName )
        XCTAssertNil(metadata.service.genre )
    }
    
    // MARK: accepted, not all keys are relevant for further use
    
    func testIcyNotEligible() {
        let metadata = IcyMetadata(icyData: ["AR-CCL":"...data..."])
        XCTAssertNil(metadata.streamUrl)
        XCTAssertFalse(metadata.eligible)
    }
    
    func testOpusAlwaysEligible() {
        let metadata = OpusMetadata(vorbisComments: ["ORGANIZATION":"...a label..."])
        XCTAssertTrue(metadata.eligible)
        print( metadata.description)
    }
    
    func testOpusEligible_Description() {
        let metadata = OpusMetadata(vorbisComments: heyJudeVorbisComments )
        XCTAssertTrue(metadata.eligible)
        print( metadata.description)
    }

    func testIcyWeakFallbackYbrid() {
        let fallback = IcyMetadata(icyData: swr3IcyYbridDemoRawOccurs)
        let ybridMD = toYbridV2Metadata(metadataRawJson)
        let metadata = YbridMetadata(ybridV2: ybridMD)
        fallback.delegate(to:  metadata)
        XCTAssertTrue(fallback.eligible)
    }
   
    func testIcyWeakFallbackIcyTitle() {
        let fallback = IcyMetadata(icyData: swr3IcyYbridDemoRawOccurs)

        let metadata = IcyMetadata(icyData: heyJudeIcyTitle)
        fallback.delegate(to:  metadata)
        XCTAssertTrue(fallback.eligible)
    }
    
    func testIcyWeakFallbackWeakIcy() {
        let fallback = IcyMetadata(icyData: swr3IcyYbridDemoRawOccurs)

        let metadata = IcyMetadata(icyData: ["AR-CCL":"...data..."])
        fallback.delegate(to:  metadata)
        XCTAssertFalse(fallback.eligible)
    }
    
    
    // MARK: icy entry StreamUrl signals possible audio complete
    
    func testIcyNoStreamUrl() {
        let metadata = IcyMetadata(icyData: heyJudeIcyTitle)
        XCTAssertNil(metadata.streamUrl)
        XCTAssertTrue(metadata.eligible)
    }
    
    func testIcyWithStreamUrl() {
        let streamUrl = "some url"
        var icyDataEx = heyJudeIcyTitle
        icyDataEx["StreamUrl"] = streamUrl
        let icyData = IcyMetadata(icyData: icyDataEx)
        XCTAssertEqual(icyData.streamUrl, streamUrl)
        XCTAssertTrue(icyData.eligible)
    }
    
    func testIcyServiceAndIcyWithStreamUrl() {
        let metadata = IcyMetadata(icyData: swr3IcyName)
        
        let streamUrl = "some url"
        var icyDataEx = heyJudeIcyTitle
        icyDataEx["StreamUrl"] = streamUrl
        let icyData = IcyMetadata(icyData: icyDataEx)
        
        metadata.delegate(to: icyData)
        XCTAssertEqual(metadata.streamUrl, streamUrl)
        
        let abstract = metadata as AbstractMetadata
        XCTAssertEqual(abstract.streamUrl, streamUrl)
    }
}
