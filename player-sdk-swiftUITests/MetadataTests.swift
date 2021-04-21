//
// MetadataTests.swift
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

import XCTest
import YbridPlayerSDK

class MetadataTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    var metadataListener:TestMetadataListener?
    func test01_Session_Ybrid_PlaySomeSeconds() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/adaptive-demo")
        let session = endpoint.createSession()
        metadataListener = TestMetadataListener()
        let player = AudioPlayer(session: session, listener: metadataListener)
        player.play()
        sleep(6)
        XCTAssertEqual(PlaybackState.playing, player.state)
        XCTAssertTrue(metadataListener!.displayTitleCalled >= 1, "expected >=1 calls, but was \(metadataListener!.displayTitleCalled)")
        player.stop()
        sleep(1)
        
        XCTAssertEqual(PlaybackState.stopped, player.state)
        player.play()
        sleep(3)
        XCTAssertEqual(PlaybackState.playing, player.state)
        XCTAssertTrue(metadataListener!.displayTitleCalled >= 2)
        player.stop()
        sleep(1)
    }
    
    func test02_Session_Icy_PlaySomeSeconds() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://hr-hr2-live.cast.addradio.de/hr/hr2/live/mp3/128/stream.mp3")
        let session = endpoint.createSession()
        metadataListener = TestMetadataListener()
        let player = AudioPlayer(session: session, listener: metadataListener)
        player.play()
        sleep(6)
        XCTAssertEqual(PlaybackState.playing, player.state)
        XCTAssertTrue(metadataListener!.displayTitleCalled >= 1)
        player.stop()
        sleep(1)
        
        XCTAssertEqual(PlaybackState.stopped, player.state)
        player.play()
        sleep(3)
        XCTAssertEqual(PlaybackState.playing, player.state)
        XCTAssertTrue(metadataListener!.displayTitleCalled >= 2)
        sleep(1)
    }
    
    class TestMetadataListener : AbstractAudioPlayerListener {
        
        var displayTitleCalled = 0
        override func displayTitleChanged(_ title: String?) {
            displayTitleCalled += 1
            Logger.testing.info("-- combined display title is \(title ?? "(nil)")")
            XCTAssertNotNil(title)
        }
        
    }
}


