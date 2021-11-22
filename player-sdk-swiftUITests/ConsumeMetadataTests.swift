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
    var player:PlaybackControl?
    var semaphore:DispatchSemaphore?
    override func setUpWithError() throws {
        semaphore = DispatchSemaphore(value: 0)
    }
    override func tearDownWithError() throws {
        player?.close()
        _ = wait(until: .stopped, maxSeconds: 3)
        consumer = TestMetadataCallsConsumer()
    }

    
    func test01_Ybrid_OnEachPlayAndInStream_FullCurrentNext() throws {

        try AudioPlayer.open (for: ybridDemoEndpoint, listener: consumer) {
            [self] control in player = control
            
            self.playCheckPlayingCheckStopPlayPlayingCheck(
                fistCheck: { consumer.checkMetadataCalls(equal:1) },
                secondCheck: { consumer.checkMetadataCalls(min:2) },
                thirdCheck: { consumer.checkMetadataCalls(min:3) }
            )
            semaphore?.signal()
        }
        _ = semaphore?.wait(timeout: .distantFuture)
        
        guard let metadata = consumer.metadatas.first else {
            XCTFail("metadatas[0] expected")
            return
        }
        
        XCTAssertNotNil(metadata.displayTitle, "expected a displayTitle" )
        
        let current = metadata.current
        XCTAssertTrue(checkIsDemoItem(current))
        
           
        guard let next = metadata.next else { XCTFail("next expected"); return }
        XCTAssertTrue(checkIsDemoItem(next))
        
        XCTAssertEqual(metadata.service.identifier,"") // no bouquet in server communication yet
    }
    
    let expectedYbridDemoTitles = ["The Winner Takes It All", "Your Personal Audio Experience", "All I Need"]
    private func checkIsDemoItem(_ item:Item) -> Bool {
        let expectedTypes = [ItemType.MUSIC, ItemType.JINGLE]
        guard let type = item.type else {
            XCTFail("type expected"); return false
        }
        XCTAssertTrue( expectedTypes.contains(type), "\(type) not expected" )
        
        guard let title = item.title else { XCTFail("title expected"); return false }
        XCTAssertTrue(expectedYbridDemoTitles.contains(title), "\(title) not expected" )

        XCTAssertNotNil(item.displayTitle,"display title expected")
        XCTAssertNil(item.version,"no version expected")
        guard let artist = item.artist else { XCTFail("artist expected"); return false }
        let expectedArtists = ["ABBA", "Ybrid® Hybrid Dynamic Live Audio Technology", "Air"]
        XCTAssertNotNil(expectedArtists.contains(artist),"one of \(expectedArtists) expected")
        
        XCTAssertNotNil(item.identifier,"id expected")
        XCTAssertNotNil(item.description,"descriptiion expected")
        XCTAssertNotNil(item.playbackLength,"playbackLength expected")
        return true
    }
    
    func test02_Ybrid_Swr3_OnEachPlayAndInStream_CurrentNextService() throws {
        
        try AudioPlayer.open(for: ybridSwr3Endpoint, listener: consumer) {
            [self] control in player = control
            
            self.playCheckPlayingCheckStopPlayPlayingCheck(
                fistCheck: { consumer.checkMetadataCalls(equal:1) },
                secondCheck: { consumer.checkMetadataCalls(min:2) },
                thirdCheck: { consumer.checkMetadataCalls(min:3) }
            )
            semaphore?.signal()
        }
        _ = semaphore?.wait(timeout: .distantFuture)
        
        
        let currentItems = consumer.metadatas.map{ $0.current }
        XCTAssertGreaterThan(currentItems.count, 0, "must be at least one current item")
        currentItems.forEach{ (item) in
            guard let type = item.type else { XCTFail("expected a type"); return }
            print("\(item)")
            XCTAssertNotEqual(ItemType.UNKNOWN, type, "\(type) not expected")
            
            XCTAssertNotNil(item.identifier)
            XCTAssertNotNil(item.title)
            XCTAssertNotNil(item.artist)
            XCTAssertNotNil(item.playbackLength)
            XCTAssertNotNil(item.description)
            XCTAssertNil(item.album)
            XCTAssertNil(item.version)
            XCTAssertNil(item.genre)
        }
        
        let nextItems = consumer.metadatas.filter{ return $0.next != nil }.map{ $0.next! }
        XCTAssertGreaterThan(nextItems.count, 0, "must be at least one next item")
        nextItems.map{ $0.type }.forEach{ (type) in
            guard let type = type else { XCTFail("expected a type"); return }
            XCTAssertNotEqual(ItemType.UNKNOWN, type, "\(type) not expected")
        }
        
        let services = consumer.metadatas.map { $0.service }
        XCTAssertGreaterThan(services.count, 0, "must be at least one station")
        services.forEach { (service) in
            XCTAssertEqual("swr3-live", service.identifier)
            XCTAssertEqual("SWR3 Live", service.displayName)
            XCTAssertNil(service.genre)
            XCTAssertNil(service.description)
            guard let iconUrl = service.iconUri else {
                XCTFail("missing iconUri for swr3 (from Ybrid bouquet header icy-url)"); return
            }
            XCTAssertTrue(iconUrl.starts(with: "http"))
            XCTAssertTrue(iconUrl.contains("swr"))
        }
    }
    
    func test03_Icy_InStreamOnly_CurrentService_InfoUrl() throws {
        
        try AudioPlayer.open(for: icecastHr2Endpoint, listener: consumer) {
            [self] control in player = control
            
            self.playCheckPlayingCheckStopPlayPlayingCheck(
                fistCheck: { consumer.checkMetadataCalls(equal:0) },
                secondCheck: { consumer.checkMetadataCalls(min:1) },
                thirdCheck: { consumer.checkMetadataCalls(min:2) }
            )
            semaphore?.signal()
        }
        _ = semaphore?.wait(timeout: .distantFuture)
    
        let currentItems = consumer.metadatas.map{ $0.current }
        XCTAssertGreaterThan(currentItems.count, 0, "must be at least one current item")

        currentItems.map{ $0.displayTitle }.forEach{ (displayTitle) in
            XCTAssertNotNil(displayTitle, "\(displayTitle) expected")
        }
        guard let firstMetadata = consumer.metadatas.first else {
            XCTFail("expected metadatas.first")
            return
        }
        XCTAssertNil(firstMetadata.next, "icy usually doesn't include next item")
        
        let service = firstMetadata.service
        XCTAssertEqual("hr2", service.identifier)
        XCTAssertEqual("hr2", service.displayName)
        XCTAssertNil(service.genre)
        XCTAssertNil(service.description)
        guard let infoUrl = service.infoUri else {
            XCTFail("missing infoUrl for hr2 (from http header icy-url)"); return
        }
        // today it's http://www.hr.de but may change to something like https://www.hr2.de
        XCTAssertTrue(infoUrl.starts(with: "http"))
        XCTAssertTrue(infoUrl.contains("www.hr"))
        XCTAssertNil(service.iconUri)
    }
    
    func test04_OpusDlf_InStreamOnly_CurrentService() throws {
        Logger.verbose = true
        
        try AudioPlayer.open(for: opusDlfEndpoint, listener: consumer) {
            [self] control in player = control
            
            self.playCheckPlayingCheckStopPlayPlayingCheck(
                fistCheck: { consumer.checkMetadataCalls(equal:0) },
                secondCheck: { consumer.checkMetadataCalls(min:1) },
                thirdCheck: { consumer.checkMetadataCalls(min:2) }
            )
            semaphore?.signal()
        }
        _ = semaphore?.wait(timeout: .distantFuture)
    
        let currentItems = consumer.metadatas.map{ $0.current }
        XCTAssertGreaterThan(currentItems.count, 0, "must be at least one current item")

        currentItems.map{ $0.displayTitle }.forEach{ (displayTitle) in
            XCTAssertNotNil(displayTitle, "\(displayTitle) expected")
        }
        
        XCTAssertNil(consumer.metadatas.first?.next, "icy usually doesn't include next item")
        
        guard let service = consumer.metadatas.first?.service else {
            XCTFail("This server supports icy-fields, 'icy-name' missing"); return
        }
        XCTAssertEqual(service.identifier, "Deutschlandfunk")
        XCTAssertEqual(service.displayName, "Deutschlandfunk")
        XCTAssertEqual(service.genre, "Information")
        XCTAssertNil(service.iconUri)
        XCTAssertEqual(service.description, "Alles von Relevanz.")
        XCTAssertEqual(service.infoUri, "https://www.deutschlandfunk.de")
    }
    
    func test05_OpusCC_InStreamOnly_TitleArtistAlbumService() throws {
        
        try AudioPlayer.open(for: opusCCEndpoint, listener: consumer) {
            [self] control in player = control
            
            self.playCheckPlayingCheckStopPlayPlayingCheck(
                fistCheck: { consumer.checkMetadataCalls(equal:0) },
                secondCheck: { consumer.checkMetadataCalls(min:1) },
                thirdCheck: { consumer.checkMetadataCalls(min:2) }
            )
            semaphore?.signal()
        }
        _ = semaphore?.wait(timeout: .distantFuture)
        
        let currentItems = consumer.metadatas.map{ $0.current }
        XCTAssertGreaterThan(currentItems.count, 1, "must be one current item")
        guard let item = currentItems.first else { XCTFail(); return }
        
        XCTAssertNil(item.type)
        XCTAssertNil(item.identifier)
        XCTAssertNotNil(item.displayTitle)
        XCTAssertNotNil(item.title)
        XCTAssertNotNil(item.artist)
        //        XCTAssertNotNil(item.album) /// depends on the track
        XCTAssertNil(item.version)
        XCTAssertNil(item.description)
        XCTAssertNotNil(item.genre)
        
        
        XCTAssertNil(consumer.metadatas[0].next, "icy usually doesn't include next item")
        
        guard let service = consumer.metadatas.first?.service else {
            XCTFail("This server supports icy-fields, 'icy-name' missing"); return
        }
        XCTAssertEqual(service.identifier, "TheRadio.CC")
        XCTAssertEqual(service.displayName, "TheRadio.CC")
        XCTAssertEqual(service.genre, "Creative Commons")
        XCTAssertNil(service.iconUri)
        XCTAssertEqual(service.description, "The Radio CC - Euer Creative Commons-Webradio")
        XCTAssertEqual(service.infoUri, "https://theradio.cc/")
    }
    
    func test06_OnDemand_OnBeginningNoneOnResume() throws {

        try AudioPlayer.open(for: onDemandOpusEndpoint, listener: consumer) {
            [self] control in player = control
            
            self.playPlayingCheckPausePlayPlayingCheck(
                fistCheck: { consumer.checkMetadataCalls(equal:1) },
                secondCheck: { consumer.checkMetadataCalls(equal:1) }
            )
            semaphore?.signal()
        }
        _ = semaphore?.wait(timeout: .distantFuture)
    
        let currentItems = consumer.metadatas.map{ $0.current }
        XCTAssertEqual(currentItems.count, 1, "must be one current item")
        guard let item = currentItems.first else { XCTFail(); return }
        XCTAssertEqual(item.album, "Lines Build Walls")
        XCTAssertEqual(item.title, "Paper Lights")
        XCTAssertEqual(item.artist, "Ehren Starks")
        XCTAssertEqual(item.displayTitle, "Lines Build Walls - Ehren Starks - Paper Lights")
        XCTAssertNil(item.description)
        XCTAssertNil(item.identifier)
        XCTAssertNil(item.version)
        XCTAssertNil(item.type)
        
        guard let metadata = consumer.metadatas.first else {
            XCTFail(); return
        }
        XCTAssertNil(metadata.next, "icy usually doesn't include next item")
        
        ///
        let service = metadata.service
        XCTAssertEqual(service.identifier,"default")
        XCTAssertNil(service.displayName, "This server does not support icy-fields")
    }
    
    
    private func playCheckPlayingCheckStopPlayPlayingCheck(fistCheck: () -> (), secondCheck: () -> (), thirdCheck: () -> () ) {
        guard let player = player else { XCTFail("no player"); return }
        player.play()
        usleep(20_000)  /// because the listener is notified asyncronously it *may* take some millis on old devices
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
        let queue = DispatchQueue(label: "io.ybrid.testing.metadata.calls")
        
        override func metadataChanged(_ metadata: Metadata) {
            Logger.testing.info("-- metadata changed, display title is '\(metadata.displayTitle)'")
//            XCTAssertNotNil(metadata.displayTitle)
            queue.async {
                self.metadatas.append(metadata)
            }
        }
        
        func checkMetadataCalls(equal expectedCalls: Int) {
            let calls = queue.sync { metadatas.count }
            XCTAssertTrue( calls == expectedCalls,  "expected == \(expectedCalls) calls, but was \(calls)")
        }
        
        /// tolerating one more is necessary because metadata can change while testing
        func checkMetadataCalls(min expectedMinCalls: Int, tolerateMore:Int = 1) {
            let calls = queue.sync { metadatas.count }
            let expectedMaxCalls = expectedMinCalls + tolerateMore
            let range = (expectedMinCalls...expectedMaxCalls)
            XCTAssertTrue( range.contains(calls), "expected \(range) calls, but was \(calls)")
        }
    }
}
