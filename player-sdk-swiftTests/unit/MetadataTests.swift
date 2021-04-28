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

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDisplayTitle_IcyOnly() {
        let metadata = Metadata(icyData: ["StreamTitle":"Beatles - Hey Jude"] )
        XCTAssertEqual("Beatles - Hey Jude", metadata.displayTitle() )
    }

    func testDisplayTitle_VorbisCommandsAreCaseSensitive() {
        let metadata = Metadata(vorbisComments: ["title":"Hey Jude", "artist":"Beatles"] )
        XCTAssertNil(metadata.displayTitle() )
    }
    
    func testDisplayTitle_OpusOnly() {
        let metadata = Metadata(vorbisComments: ["TITLE":"Hey Jude", "ARTIST":"Beatles"] )
        XCTAssertEqual("Beatles - Hey Jude", metadata.displayTitle() )
    }
    
    func testDisplayTitle_OpusMaxSyntax() {
        let metadata = Metadata(vorbisComments: ["TITLE":"Hey Jude", "ARTIST":"Beatles",
                                    "ALBUM":"Love", "VERSION":"Remastered 2015"] )
        XCTAssertEqual("Love - Beatles - Hey Jude (Remastered 2015)", metadata.displayTitle() )
    }
    
    func testDisplayTitle_ybridOnly() {
        let ybridMD = YbridMetadata(currentItem: heyJude, nextItem: noTitle, station: ybridDemo)
        let metadata = Metadata(ybridMetadata: ybridMD)
        XCTAssertEqual("Hey Jude\nby Beatles", metadata.displayTitle() )
    }

    func testDisplayTitle_icyAndYbrid_YbridWins() {
        let metadata = Metadata(icyData: ["StreamTitle":"Beatles - Hey Jude"] )
        let ybridMD = YbridMetadata(currentItem: heyJude, nextItem: noTitle, station: ybridDemo)
        metadata.ybridMetadata = ybridMD
        XCTAssertEqual("Hey Jude\nby Beatles", metadata.displayTitle() )
    }
    
    func testDisplayTitle_OpusAndYbrid_YbridWins() {
        let metadata = Metadata(vorbisComments: ["TITLE":"Hey Jude", "ARTIST":"Beatles",
                                    "ALBUM":"Love", "VERSION":"Remastered 2015"] )
        let ybridMD = YbridMetadata(currentItem: heyJude, nextItem: noTitle, station: ybridDemo)
        metadata.ybridMetadata = ybridMD
        XCTAssertEqual("Hey Jude\nby Beatles", metadata.displayTitle() )
    }
    
    
    let heyJude = YbridItem(id: "anyId", artist: "Beatles", title: "Hey Jude", description: "test song", durationMillis: 238000, companions: [], type: "MUSIC")
    let noTitle = YbridItem(id: "otherId", artist: "", title: "", description: "", durationMillis: 0, companions: [], type: "")
    let ybridDemo = YbridStation(genre: "", name: "")
}
