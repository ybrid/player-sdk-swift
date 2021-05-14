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
    
    let ybridDemoEndpoint = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/adaptive-demo")
    let ybridSwr3Endpoint = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/swr3/mp3/mid")
    let icecastHr2Endpoint = MediaEndpoint(mediaUri: "https://hr-hr2-live.cast.addradio.de/hr/hr2/live/mp3/128/stream.mp3")
    let opusDlfEndpoint = MediaEndpoint(mediaUri: "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")
    let opusCCEndpoint = MediaEndpoint(mediaUri: "http://theradio.cc:8000/trcc-stream.opus")
    let onDemandEndpoint = MediaEndpoint(mediaUri: "https://opus-codec.org/static/examples/ehren-paper_lights-96.opus")
    
    
    var consumer = TestMetadataCallsConsumer()
    var mediaSession:MediaSession?
    var player:AudioPlayer?
    override func setUpWithError() throws { }
    override func tearDownWithError() throws {
        player?.close()
        consumer = TestMetadataCallsConsumer()
    }

    
    func test01_MetadataYbrid_OnEachPlayAndInStream() {
        player = ybridDemoEndpoint.audioPlayer(listener: consumer)
        self.playCheckPlayingCheckStopPlayPlayingCheck(
            fistCheck: { consumer.checkMetadataCalls(equal:1) },
            secondCheck: { consumer.checkMetadataCalls(min:2) },
            thirdCheck: { consumer.checkMetadataCalls(min:3) }
        )
    }

    func test02_MetadataIcy_InStreamOnly() {
        player = icecastHr2Endpoint.audioPlayer(listener: consumer)
        self.playCheckPlayingCheckStopPlayPlayingCheck(
            fistCheck: { consumer.checkMetadataCalls(equal:0) },
            secondCheck: { consumer.checkMetadataCalls(min:1) },
            thirdCheck: { consumer.checkMetadataCalls(min:2) }
        )
    }
    
    func test03_MetadataOpus_InStreamOnly() throws {
        player = opusDlfEndpoint.audioPlayer(listener: consumer)
        self.playCheckPlayingCheckStopPlayPlayingCheck(
            fistCheck: { consumer.checkMetadataCalls(equal:0) },
            secondCheck: { consumer.checkMetadataCalls(min:1) },
            thirdCheck: { consumer.checkMetadataCalls(min:2) }
        )
    }
    
    func test04_MetadataOnDemand_OnBeginningNoneOnResume() throws {
        player = onDemandEndpoint.audioPlayer(listener: consumer)
        self.playPlayingCheckPausePlayPlayingCheck(
            fistCheck: { consumer.checkMetadataCalls(equal:1) },
            secondCheck: { consumer.checkMetadataCalls(equal:1) }
        )
    }
    
    
    func test05_MetadataYbrid_Demo_FullCurrentItem() {
        player = ybridDemoEndpoint.audioPlayer(listener: consumer)
        player?.play()
        consumer.checkMetadataCalls(equal: 1)
        player?.stop()
        _ = wait(until: .stopped, maxSeconds: 2)
        
        let metadata = consumer.metadatas[0]
        guard let current = metadata.current else { XCTFail("current expected"); return }
        let expectedTypes = [ItemType.MUSIC, ItemType.JINGLE]
        XCTAssertTrue( expectedTypes.contains(current.type), "\(current.type) not expected" )
        
        guard let title = current.title else { XCTFail("title expected"); return }
        let expectedTitles = ["The Winner Takes It All", "Your Personal Audio Experience", "All I Need"]
        XCTAssertTrue(expectedTitles.contains(title), "\(title) not expected" )

        XCTAssertNotNil(current.displayTitle,"display title expected")
        XCTAssertNil(current.version,"no version expected")
        guard let artist = current.artist else { XCTFail("artist expected"); return }
        let expectedArtists = ["ABBA", "Ybrid® Hybrid Dynamic Live Audio Technology", "Air"]
        XCTAssertNotNil(expectedArtists.contains(artist),"one of \(expectedArtists) expected")
        
        XCTAssertNotNil(current.identifier,"id expected")
        XCTAssertNotNil(current.description,"descriptiion expected")
        XCTAssertNotNil(current.durationMillis,"durationMillis expected")
 
    }
    
    
    func test06_MetadataYbrid_Swr3_CurrentNextStation() {
        player = ybridSwr3Endpoint.audioPlayer(listener: consumer)
        player?.play()
        consumer.checkMetadataCalls(equal: 1)
        player?.stop()
        
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
        
        guard let station = consumer.metadatas[0].station else {
            XCTFail(); return
        }
        XCTAssertEqual("SWR3", station.name)
        XCTAssertEqual("Pop Music", station.genre)

        _ = wait(until: .stopped, maxSeconds: 2)
    }
    
    func test07_MetadataIcy_Hr2_CurrentStation() {
        player = icecastHr2Endpoint.audioPlayer(listener: consumer)
        player?.play()
        _ = wait(until: .playing, maxSeconds: 10)
        consumer.checkMetadataCalls(equal: 1)
        player?.stop()
        
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
        
        _ = wait(until: .stopped, maxSeconds: 1)
    }
    
    func test08_MetadataOpus_Dlf_CurrentStation() {
        player = opusDlfEndpoint.audioPlayer(listener: consumer)
        player?.play()
        _ = wait(until: .playing, maxSeconds: 10)
        consumer.checkMetadataCalls(equal: 1)
        player?.stop()
        
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
        
        _ = wait(until: .stopped, maxSeconds: 1)
    }

    func test08_MetadataOpus_CC_CurrentStation() {
        player = opusCCEndpoint.audioPlayer(listener: consumer)
        player?.play()
        _ = wait(until: .playing, maxSeconds: 10)
        consumer.checkMetadataCalls(equal: 1)
        player?.stop()
        
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
        XCTAssertEqual("TheRadio.CC", station.name)
        XCTAssertEqual("Creative Commons", station.genre)
        
        _ = wait(until: .stopped, maxSeconds: 1)
    }

    
    
    func test09_MetadataOpusOnDemand_TitleArtistAlbum() {
        player = onDemandEndpoint.audioPlayer(listener: consumer)
        player?.play()
        _ = wait(until: .playing, maxSeconds: 10)
        consumer.checkMetadataCalls(equal: 1)
        player?.stop()
        
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
        
        _ = wait(until: .stopped, maxSeconds: 1)
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

