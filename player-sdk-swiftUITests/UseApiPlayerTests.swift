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
    
    var session:MediaSession? { willSet {
        if let lastSession = session {
            lastSession.close()
        }
    }}

    override func setUpWithError() throws {
        // Log additional debug information in this tests
        Logger.verbose = true
    }
    
    override func tearDownWithError() throws {
    }
    
    func test01_Session_Ybrid_PlaySomeSeconds() throws {
//        let uri = "https://stagecast.ybrid.io/swr3/mp3/mid"
        let uri = "https://stagecast.ybrid.io/adaptive-demo"
        self.session = MediaEndpoint(mediaUri: uri).createSession()
        let player = AudioPlayer(session: session!, listener: nil)
        player.play()
        _ = wait(player, until: .playing, maxSeconds: 10)
        sleep(3)
        player.stop()
        _ = wait(player, until: .stopped, maxSeconds: 2)
    }
    
    func test02_Session_WrongUrl_PlayStops() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/wrongurl")
        session = endpoint.createSession()
        let player = AudioPlayer(session: session!, listener: nil)
        player.play()
        _ = wait(player, until: .stopped, maxSeconds: 2)
    }

    func test03_Session_Icy_PlaySomeSeconds() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://hr-hr2-live.cast.addradio.de/hr/hr2/live/mp3/128/stream.mp3")
        session = endpoint.createSession()
        let player = AudioPlayer(session: session!, listener: nil)
        player.play()
        _ = wait(player, until: .playing, maxSeconds: 10)
        sleep(3)
        player.stop()
        _ = wait(player, until: .stopped, maxSeconds: 2)
    }

    func test04_Session_Opus_PlaySomeSeconds() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")
        session = endpoint.createSession()
        let player = AudioPlayer(session: session!, listener: nil)
        player.play()
        _ = wait(player, until: .playing, maxSeconds: 10)
        sleep(3)
        player.stop()
        _ = wait(player, until: .stopped, maxSeconds: 2)
    }

    func test05_Session_Icy_OnDemand_PlayPausePlay() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://github.com/ybrid/test-files/blob/main/mpeg-audio/music/organ.mp3?raw=true")
        session = endpoint.createSession()
        let player = AudioPlayer(session: session!, listener: nil)
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
