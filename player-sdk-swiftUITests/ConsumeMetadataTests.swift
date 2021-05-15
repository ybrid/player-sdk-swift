// ConsumeMetadataTests.swift
//
// player-sdk-swiftUITests
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
import YbridPlayerSDK

class ConsumeMetadataTests: XCTestCase {
    
    
    var consumer = TestMetadataCallsConsumer()
    var mediaSession:MediaSession?
    var player:AudioPlayer?
    override func setUpWithError() throws { }
    override func tearDownWithError() throws {
        player?.close()
        consumer = TestMetadataCallsConsumer()
    }


    func test01_MetadataYbrid_OnEachPlayAndInStream_FullCurrentNext() {
        player = AudioPlayer.open(for: ybridDemoEndpoint, listener: consumer)
        self.playCheckPlayingCheckStopPlayPlayingCheck(
            fistCheck: { consumer.checkMetadataCalls(equal:1) },
            secondCheck: { consumer.checkMetadataCalls(min:2) },
            thirdCheck: { consumer.checkMetadataCalls(min:3) }
        )
                
        let metadata = consumer.metadatas[0]
        guard let current = metadata.current else { XCTFail("current expected"); return }
        XCTAssertTrue(checkIsDemoItem(current))
        
           
        guard let next = metadata.next else { XCTFail("next expected"); return }
        XCTAssertTrue(checkIsDemoItem(next))
        
        guard let _ = metadata.station else { XCTFail("next expected"); return }
        
    }
    
    
    private func checkIsDemoItem(_ item:Item) -> Bool {
        let expectedTypes = [ItemType.MUSIC, ItemType.JINGLE]
        XCTAssertTrue( expectedTypes.contains(item.type), "\(item.type) not expected" )
        
        guard let title = item.title else { XCTFail("title expected"); return false }
        let expectedTitles = ["The Winner Takes It All", "Your Personal Audio Experience", "All I Need"]
        XCTAssertTrue(expectedTitles.contains(title), "\(title) not expected" )

        XCTAssertNotNil(item.displayTitle,"display title expected")
        XCTAssertNil(item.version,"no version expected")
        guard let artist = item.artist else { XCTFail("artist expected"); return false }
        let expectedArtists = ["ABBA", "Ybrid® Hybrid Dynamic Live Audio Technology", "Air"]
        XCTAssertNotNil(expectedArtists.contains(artist),"one of \(expectedArtists) expected")
        
        XCTAssertNotNil(item.identifier,"id expected")
        XCTAssertNotNil(item.description,"descriptiion expected")
        XCTAssertNotNil(item.durationMillis,"durationMillis expected")
        return true
    }
    
    func test02_MetadataYbrid_Swr3_OnEachPlayAndInStream_CurrentNextStation() {
        player = AudioPlayer.open(for: ybridStageSwr3Endpoint, listener: consumer)
        self.playCheckPlayingCheckStopPlayPlayingCheck(
            fistCheck: { consumer.checkMetadataCalls(equal:1) },
            secondCheck: { consumer.checkMetadataCalls(min:2) },
            thirdCheck: { consumer.checkMetadataCalls(min:3) }
        )
        
        let currentItems = consumer.metadatas.filter{ return $0.current != nil }.map{ $0.current! }
        XCTAssertGreaterThan(currentItems.count, 0, "must be at least one current item")
        currentItems.map{ $0.type }.forEach{ (type) in
            XCTAssertNotEqual(ItemType.UNKNOWN, type, "\(type) not expected")
        }
        
        let nextItems = consumer.metadatas.filter{ return $0.next != nil }.map{ $0.next! }
        XCTAssertGreaterThan(nextItems.count, 0, "must be at least one next item")
        nextItems.map{ $0.type }.forEach{ (type) in
            XCTAssertNotEqual(ItemType.UNKNOWN, type, "\(type) not expected")
        }
        
        let stations = consumer.metadatas.filter{ return $0.station != nil }.map { $0.station! }
        XCTAssertGreaterThan(stations.count, 0, "must be at least one station")
        stations.forEach { (station) in
            XCTAssertEqual("SWR3", station.name)
            XCTAssertEqual("Pop Music", station.genre)
        }
    }

    
    func test03_MetadataIcy_InStreamOnly_CurrentStation() {
        player = AudioPlayer.open(for: icecastHr2Endpoint, listener: consumer)
        self.playCheckPlayingCheckStopPlayPlayingCheck(
            fistCheck: { consumer.checkMetadataCalls(equal:0) },
            secondCheck: { consumer.checkMetadataCalls(min:1) },
            thirdCheck: { consumer.checkMetadataCalls(min:2) }
        )
        
        let currentItems = consumer.metadatas.filter{ return $0.current != nil }.map{ $0.current! }
        XCTAssertGreaterThan(currentItems.count, 0, "must be at least one current item")
        currentItems.map{ $0.type }.forEach{ (type) in
            XCTAssertEqual(ItemType.UNKNOWN, type, "\(type) not expected")
        }
        currentItems.map{ $0.displayTitle }.forEach{ (displayTitle) in
            XCTAssertNotNil(displayTitle, "\(displayTitle) expected")
        }
        
        XCTAssertNil(consumer.metadatas[0].next, "icy usually doesn't include next item")
        
        guard let station = consumer.metadatas[0].station else {
            XCTFail("icy usually uses http-header 'icy-name'"); return
        }
        XCTAssertEqual("hr2", station.name)
        XCTAssertNil(station.genre)
        
    }
    
    func test04_MetadataOpusDlf_InStreamOnly_CurrentStation() throws {
        player = AudioPlayer.open(for: opusDlfEndpoint, listener: consumer)
        self.playCheckPlayingCheckStopPlayPlayingCheck(
            fistCheck: { consumer.checkMetadataCalls(equal:0) },
            secondCheck: { consumer.checkMetadataCalls(min:1) },
            thirdCheck: { consumer.checkMetadataCalls(min:2) }
        )
        
        let currentItems = consumer.metadatas.filter{ return $0.current != nil }.map{ $0.current! }
        XCTAssertGreaterThan(currentItems.count, 0, "must be at least one current item")
        currentItems.map{ $0.type }.forEach{ (type) in
            XCTAssertEqual(ItemType.UNKNOWN, type, "\(type) not expected")
        }
        currentItems.map{ $0.displayTitle }.forEach{ (displayTitle) in
            XCTAssertNotNil(displayTitle, "\(displayTitle) expected")
        }
        
        XCTAssertNil(consumer.metadatas[0].next, "icy usually doesn't include next item")
        
        guard let station = consumer.metadatas[0].station else {
            XCTFail("icy usually uses http-header 'icy-name'"); return
        }
        XCTAssertEqual("Deutschlandfunk", station.name)
        XCTAssertEqual("Information", station.genre)

    }
    
    func test05_MetadataOpusCC_InStreamOnly_TitleArtistAlbum() throws {
        player = AudioPlayer.open(for: opusCCEndpoint, listener: consumer)
        self.playCheckPlayingCheckStopPlayPlayingCheck(
            fistCheck: { consumer.checkMetadataCalls(equal:0) },
            secondCheck: { consumer.checkMetadataCalls(min:1) },
            thirdCheck: { consumer.checkMetadataCalls(min:2) }
        )
        
        let currentItems = consumer.metadatas.filter{ return $0.current != nil }.map{ $0.current }
        XCTAssertGreaterThan(currentItems.count, 1, "must be one current item")
        guard let item = currentItems[0] else { XCTFail(); return }
        
        XCTAssertNotNil(item.album)
        XCTAssertNotNil(item.title)
        XCTAssertNotNil(item.artist)
        XCTAssertNotNil(item.displayTitle)
        XCTAssertNil(item.description)
        XCTAssertNil(item.identifier)
        XCTAssertNil(item.version)
        XCTAssertEqual(ItemType.UNKNOWN, item.type)
        
        
        XCTAssertNil(consumer.metadatas[0].next, "icy usually doesn't include next item")
        
        guard let station = consumer.metadatas[0].station else {
            XCTFail("This server supports icy-fields, 'icy-name' missing"); return
        }
        XCTAssertEqual("TheRadio.CC", station.name)
        XCTAssertEqual("Creative Commons", station.genre)
    }
    
    func test06_MetadataOnDemand_OnBeginningNoneOnResume() throws {
        player = AudioPlayer.open(for: onDemandOpusEndpoint, listener: consumer)
        self.playPlayingCheckPausePlayPlayingCheck(
            fistCheck: { consumer.checkMetadataCalls(equal:1) },
            secondCheck: { consumer.checkMetadataCalls(equal:1) }
        )
        
        let currentItems = consumer.metadatas.filter{ return $0.current != nil }.map{ $0.current }
        XCTAssertEqual(currentItems.count, 1, "must be one current item")
        guard let item = currentItems[0] else { XCTFail(); return }
        XCTAssertNotNil(item.album)
        XCTAssertNotNil(item.title)
        XCTAssertNotNil(item.artist)
        XCTAssertNotNil(item.displayTitle)
        XCTAssertNil(item.description)
        XCTAssertNil(item.identifier)
        XCTAssertNil(item.version)
        XCTAssertEqual(ItemType.UNKNOWN, item.type)
        
        
        XCTAssertNil(consumer.metadatas[0].next, "icy usually doesn't include next item")
        
        let station = consumer.metadatas[0].station
        XCTAssertNil(station, "This server does not support icy-fields")
    }
    
     
       
    

    
    private func playCheckPlayingCheckStopPlayPlayingCheck(fistCheck: () -> (), secondCheck: () -> (), thirdCheck: () -> () ) {
        guard let player = player else { XCTFail("no player"); return }
        player.play()
        fistCheck()
        var seconds = wait(until: .playing, maxSeconds: 10)
        Logger.testing.debug("took \(seconds) second\(seconds == 1 ? "" : "s") until \(player.state)")
        secondCheck()
        player.stop()
        _ = wait(until: .stopped, maxSeconds: 3)
        
        player.play()
        seconds = wait(until: .playing, maxSeconds: 10)
        Logger.testing.debug("took \(seconds) second\(seconds == 1 ? "" : "s") until \(player.state)")
        thirdCheck()
        player.stop()
        _ = wait(until: .stopped, maxSeconds: 2)
    }
    
    private func playPlayingCheckPausePlayPlayingCheck(fistCheck: () -> (), secondCheck: () -> () ) {
        guard let player = player else { XCTFail("no player"); return }
        player.play()
        var seconds = wait(until: .playing, maxSeconds: 10)
        Logger.testing.debug("took \(seconds) second\(seconds == 1 ? "" : "s") until \(player.state)")
        fistCheck()
        player.pause()
        _ = wait(until: .pausing, maxSeconds: 2)

        player.play()
        seconds = wait(until: .playing, maxSeconds: 10)
        Logger.testing.debug("took \(seconds) second\(seconds == 1 ? "" : "s") until \(player.state)")
        secondCheck()
        player.stop()
        _ = wait(until: .stopped, maxSeconds: 2)
    }
    
    private func wait(until:PlaybackState, maxSeconds:Int) -> Int {
        guard let player = player else { XCTFail("no player"); return -1 }
        var seconds = 0
        while player.state != until && seconds < maxSeconds {
            sleep(1)
            seconds += 1
        }
        XCTAssertEqual(until, player.state, "not \(until) within \(maxSeconds) s")
        return seconds
    }
    
    class TestMetadataCallsConsumer : AbstractAudioPlayerListener {
        
        var metadatas:[Metadata] = []
        
        override func metadataChanged(_ metadata: Metadata) {
            metadatas.append(metadata)
            Logger.testing.info("-- metadata changed, display title is \(metadata.displayTitle ?? "(nil)")")
            XCTAssertNotNil(metadata.displayTitle)
        }
        
        func checkMetadataCalls(equal expectedCalls: Int) {
            let calls = metadatas.count
            XCTAssertTrue( calls == expectedCalls,  "expected == \(expectedCalls) calls, but was \(calls)")
        }
        
        /// tolerating one more is necessary because metadata can change while testing
        func checkMetadataCalls(min expectedMinCalls: Int, tolerateMore:Int = 1) {
            let calls = metadatas.count
            let expectedMaxCalls = expectedMinCalls + tolerateMore
            let range = (expectedMinCalls...expectedMaxCalls)
            XCTAssertTrue( range.contains(calls), "expected \(range) calls, but was \(calls)")
        }
    }
}
