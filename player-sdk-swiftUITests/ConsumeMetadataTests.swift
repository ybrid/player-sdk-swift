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
    
    let ybridEndpoint = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/adaptive-demo")
    let icecastEndpoint = MediaEndpoint(mediaUri: "https://hr-hr2-live.cast.addradio.de/hr/hr2/live/mp3/128/stream.mp3")
    let opusEndpoint = MediaEndpoint(mediaUri: "http://theradio.cc:8000/trcc-stream.opus")
    let onDemandEndpoint = MediaEndpoint(mediaUri: "https://opus-codec.org/static/examples/ehren-paper_lights-96.opus")
    
    
    var consumer = TestMetadataCallsConsumer()
    var mediaSession:MediaSession?
    override func setUpWithError() throws { }
    override func tearDownWithError() throws {
        mediaSession?.close()
        consumer = TestMetadataCallsConsumer()
    }
    
    
    func test01_MetadataYbrid_ImmediatelyOnPlay() {
        mediaSession = ybridEndpoint.createSession()
        let player = AudioPlayer(session: mediaSession!, listener: consumer)
        self.playCheck5SecCheck(on: player,
                                fistCheck: { consumer.checkMetadataCalls(equal:1) },
                                secondCheck: { consumer.checkMetadataCalls(min:2) }
        )
    }
    
    func test02_MetadataYbrid_OnPlayAndInStream() {
        mediaSession = ybridEndpoint.createSession()
        let player = AudioPlayer(session: mediaSession!, listener: consumer)
        self.play5SecCheckStopPlay3SecCheck(on: player,
                                            fistCheck: { consumer.checkMetadataCalls(min:2) },
                                            secondCheck: { consumer.checkMetadataCalls(min:3) }
        )
    }
    
    func test03_MetadataYbrid_DemoStreamMetadata() {
        mediaSession = ybridEndpoint.createSession()
        let player = AudioPlayer(session: mediaSession!, listener: consumer)
        player.play()
        player.stop()
        sleep(1)
        consumer.checkMetadataCalls(equal: 1)
        
        let expectedTypes = [ItemType.MUSIC, ItemType.JINGLE]
        let types = consumer.metadatas.map{ $0.current?.type }
        XCTAssertTrue(types.count > 0)
        let type = types[0]!
        XCTAssertTrue(expectedTypes.contains(type), "\(type) not expected" )
        
        let expectedTitles = ["The Winner Takes It All", "Your Personal Audio Experience", "All I Need"]
        let titles = consumer.metadatas.map{ $0.current?.title }
        XCTAssertTrue(titles.count > 0)
        let title = titles[0]!
        XCTAssertTrue(expectedTitles.contains(title), "\(title) not expected" )
    }
 
    func test04_MetadataIcy_InStreamOnly() throws {
        mediaSession = icecastEndpoint.createSession()
        let player = AudioPlayer(session: mediaSession!, listener: consumer)
        self.playCheck5SecCheck(on: player,
                                fistCheck: { consumer.checkMetadataCalls(equal:0) },
                                secondCheck: { consumer.checkMetadataCalls(min:1) }
        )
    }
    
    func test05_MetadataIcy_OnEachBeginningStream() throws {
        mediaSession = icecastEndpoint.createSession()
        let player = AudioPlayer(session: mediaSession!, listener: consumer)
        self.play5SecCheckStopPlay3SecCheck(on: player,
                                            fistCheck: { consumer.checkMetadataCalls(min:1) },
                                            secondCheck: { consumer.checkMetadataCalls(min:2) }
        )
    }
    
    func test06_MetadataIcy_Hr2StreamMetadata() {
        mediaSession = icecastEndpoint.createSession()
        let player = AudioPlayer(session: mediaSession!, listener: consumer)
        self.playCheck5SecCheck(on: player, fistCheck: {},
                                secondCheck: { consumer.checkMetadataCalls(min:1) })
        
        let types = consumer.metadatas.map{ $0.current?.type }
        guard types.count > 0 else {
            XCTFail(); return
        }
        XCTAssertTrue(types.count > 0)
        let type = types[0]!
        XCTAssertTrue(type == ItemType.UNKNOWN, "type '\(type)' not expected " )
    }
    
    func test07_MetadataOpus_OnEachBeginningStream() throws {
        mediaSession = opusEndpoint.createSession()
        let player = AudioPlayer(session: mediaSession!, listener: consumer)
        self.play5SecCheckStopPlay3SecCheck(on: player,
                                            fistCheck: { consumer.checkMetadataCalls(min:1) },
                                            secondCheck: { consumer.checkMetadataCalls(min:2) }
        )
    }
    
    func test08_MetadataOnDemand_OnBeginningNoneOnResume() throws {
        mediaSession = onDemandEndpoint.createSession()
        let player = AudioPlayer(session: mediaSession!, listener: consumer)
        self.play5SecCheckPausePlay3SecCheck(on: player,
                                             fistCheck: { consumer.checkMetadataCalls(equal:1) },
                                             secondCheck: { consumer.checkMetadataCalls(equal:1) }
        )
    }
    
    private func playCheck5SecCheck(on player: AudioPlayer, fistCheck: () -> (), secondCheck: () -> () ) {
        player.play()
        fistCheck()
        sleep(5)
        XCTAssertEqual(PlaybackState.playing, player.state)
        secondCheck()
        player.stop()
        sleep(1)
    }
    
    private func play5SecCheckStopPlay3SecCheck(on player: AudioPlayer, fistCheck: () -> (), secondCheck: () -> () ) {
        player.play()
        sleep(5)
        XCTAssertEqual(PlaybackState.playing, player.state)
        fistCheck()
        player.stop()
        sleep(1)
        XCTAssertEqual(PlaybackState.stopped, player.state)
        
        player.play()
        sleep(3)
        XCTAssertEqual(PlaybackState.playing, player.state)
        secondCheck()
        player.stop()
        sleep(1)
    }
    
    private func play5SecCheckPausePlay3SecCheck(on player: AudioPlayer, fistCheck: () -> (), secondCheck: () -> () ) {
        player.play()
        sleep(5)
        XCTAssertEqual(PlaybackState.playing, player.state)
        fistCheck()
        player.pause()
        sleep(1)
        XCTAssertEqual(PlaybackState.pausing, player.state)
        
        player.play()
        sleep(3)
        XCTAssertEqual(PlaybackState.playing, player.state)
        secondCheck()
        player.stop()
        sleep(1)
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
