//
// UseApiPlayerTests.swift
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

class UseApiPlayerTests: XCTestCase {
    
    var player:AudioPlayer? { willSet {
        if let lastPlayer = player {
            lastPlayer.close()
        }
    }}

    let playerListener = TestAudioPlayerListener()
    override func setUpWithError() throws {
        // Log additional debug information in this tests
        Logger.verbose = true
        playerListener.errors.removeAll()
    }
    
    override func tearDownWithError() throws {
    }
    
    func test01_Ybrid_PlaySomeSeconds() throws {
//        let uri = "https://stagecast.ybrid.io/swr3/mp3/mid"
        let uri = "https://stagecast.ybrid.io/adaptive-demo"
        let endpoint = MediaEndpoint(mediaUri: uri)
        player = endpoint.audioPlayer(listener: nil)
        guard let player = player else {
            XCTFail(); return
        }
        XCTAssertEqual(MediaProtocol.ybridV2, player.session?.mediaProtocol)
        
        player.play()
        _ = wait(player, until: .playing, maxSeconds: 10)
        sleep(3)
        player.stop()
        _ = wait(player, until: .stopped, maxSeconds: 2)
    }
    
    
    func test02_WrongUrl_PlayStops() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/wrongurl")
        player = endpoint.audioPlayer(listener: playerListener)
        guard let player = player else {
            XCTFail(); return
        }
        XCTAssertEqual(MediaProtocol.icy, player.session?.mediaProtocol)
        player.play()
        _ = wait(player, until: .stopped, maxSeconds: 2)
        XCTAssertEqual(1, playerListener.errors.count)
        let lastError = playerListener.errors.last!
        XCTAssertNotEqual(0, lastError.code)
        XCTAssertNotEqual(0, lastError.osstatus)
    }

    func test03_Icy_PlaySomeSeconds() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://hr-hr2-live.cast.addradio.de/hr/hr2/live/mp3/128/stream.mp3")
        player = endpoint.audioPlayer(listener: nil)
        guard let player = player else {
            XCTFail(); return
        }
        XCTAssertEqual(MediaProtocol.icy, player.session?.mediaProtocol)
        player.play()
        _ = wait(player, until: .playing, maxSeconds: 10)
        sleep(3)
        player.stop()
        _ = wait(player, until: .stopped, maxSeconds: 2)
    }

    func test04_Icy_Opus_PlaySomeSeconds() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")
        player = endpoint.audioPlayer(listener: playerListener)
        guard let player = player else {
            XCTFail(); return
        }
        XCTAssertEqual(MediaProtocol.icy, player.session?.mediaProtocol)
        
        player.play()
        _ = wait(player, until: .playing, maxSeconds: 10)
        sleep(3)
        player.stop()
        _ = wait(player, until: .stopped, maxSeconds: 2)
    }

    func test05_Session_Icy_OnDemand_PlayPausePlay() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://github.com/ybrid/test-files/blob/main/mpeg-audio/music/organ.mp3?raw=true")
        player = endpoint.audioPlayer(listener: playerListener)
        guard let player = player else {
            XCTFail(); return
        }
        XCTAssertEqual(MediaProtocol.icy, player.session?.mediaProtocol)
        player.play()
        _ = wait(player, until: .playing, maxSeconds: 10)
        sleep(3)
        player.pause()
        _ = wait(player, until: .pausing, maxSeconds: 2)
        player.play()
        _ = wait(player, until: .playing, maxSeconds: 10)
        sleep(1)
        player.stop()
        _ = wait(player, until: .stopped, maxSeconds: 2)
    }
    
    /*
     You want to see a problem?
     */
    func test06_Error_NoPlayer_HostNotFound() {
        let endpoint = MediaEndpoint(mediaUri: "https://swr-swr3.cast.io/bad/url")
        player = endpoint.audioPlayer(listener: playerListener)
        XCTAssertNil(player)

        XCTAssertEqual(1, playerListener.errors.count)
        let error = playerListener.errors[0]
        XCTAssertNotEqual(0, error.code)
        XCTAssertEqual(-1003, error.osstatus) // host not found
    }
    
    func test07_Icy_CannotProcessMimetype() {
        let endpoint = MediaEndpoint(mediaUri: "https://www.google.de")
        player = endpoint.audioPlayer(listener: playerListener)
        guard let player = player else {
            XCTFail(); return
        }
        XCTAssertEqual(0, playerListener.errors.count)
        player.play()
        sleep(1)
        let error = playerListener.errors[0]
        XCTAssertNotEqual(0, error.code)
        XCTAssertTrue(error.localizedDescription.contains("MimeType"), error.localizedDescription )
    }
    
    private func wait(_ player:AudioPlayer, until:PlaybackState, maxSeconds:Int) -> Int {
        var seconds = 0
        while player.state != until && seconds <= maxSeconds {
            sleep(1)
            seconds += 1
        }
        print("took \(seconds) second\(seconds > 1 ? "s" : "") until \(player.state)")
        XCTAssertEqual(until, player.state)
        return seconds
    }

}
