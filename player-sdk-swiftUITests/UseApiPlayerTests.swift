//
// UseApiPlayerTests.swift
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

class UseApiPlayerTests: XCTestCase {
    
    var session:Session? { willSet {
        if let lastSession = session {
            lastSession.close()
        }
    }}

    override func setUpWithError() throws {
        // Log additional debug information in this tests
//        Logger.verbose = true
    }
    
    override func tearDownWithError() throws {
        session = nil
    }
    
    func test01_Session_Ybrid_PlaySomeSeconds() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/adaptive-demo")
        session = endpoint.createSession()
        let player = AudioPlayer(session: session!, listener: nil)
        player.play()
        sleep(6)
        XCTAssertEqual(PlaybackState.playing, player.state)
        player.stop()
        sleep(1)
    }
    
//    func test02_SessionSwr3_PlaySomeSeconds() throws {
//        let endpoint = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/swr3/mp3/mid")
//        session = endpoint.createSession()
//        let player = AudioPlayer(session: session!, listener: nil)
//        player.play()
//        sleep(6)
//        player.stop()
//        sleep(1)
//
//    }
//
    func test02_Session_WrongUrl_PlayStops() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/wrongurl")
        session = endpoint.createSession()
        let player = AudioPlayer(session: session!, listener: nil)
        player.play()
        sleep(2)
        XCTAssertEqual(PlaybackState.stopped, player.state)
    }
    
    func test03_Session_Icy_PlaySomeSeconds() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://hr-hr2-live.cast.addradio.de/hr/hr2/live/mp3/128/stream.mp3")
        session = endpoint.createSession()
        let player = AudioPlayer(session: session!, listener: nil)
        player.play()
        sleep(6)
        XCTAssertEqual(PlaybackState.playing, player.state)
        player.stop()
        sleep(1)
    }
    
//    waitUntilPlaying(player, maxSeconds: 10)
//    print("\ntook \(tookSeconds) second\(tookSeconds > 1 ? "s" : "") until playing")
//    private func waitUntilPlaying(_ player:AudioPlayer, maxSeconds:Int) {
//        let semaphore = DispatchSemaphore(value: 0)
//        DispatchQueue.main.async {
//            var seconds = 0
//            repeat {
//                print(". \(player.state)"); sleep(1)
//                seconds += 1
//            } while player.state == PlaybackState.buffering && seconds < maxSeconds
//            semaphore.signal()
//        }
//        _ = semaphore.wait(timeout: .distantFuture)
//        return
//    }
    
    func test04_Session_Icy_Opus_PlaySomeSeconds() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")
        session = endpoint.createSession()
        let player = AudioPlayer(session: session!, listener: nil)
        player.play()
        sleep(6)
        XCTAssertEqual(PlaybackState.playing, player.state)
        player.stop()
        sleep(1)
    }
    
    func test05_Session_Icy_OnDemand_PlayPausePlay() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://github.com/ybrid/test-files/blob/main/mpeg-audio/music/organ.mp3?raw=true")
        session = endpoint.createSession()
        let player = AudioPlayer(session: session!, listener: nil)
        player.play()
        sleep(4)
        XCTAssertEqual(PlaybackState.playing, player.state)
        player.pause()
        sleep(1)
        XCTAssertEqual(PlaybackState.pausing, player.state)
        player.play()
        sleep(3)
        player.stop()
        sleep(1)
    }
}
