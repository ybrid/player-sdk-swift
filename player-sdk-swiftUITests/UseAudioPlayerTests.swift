//
// UseAudioPlayerTests.swift
// player-sdk-swiftUITests
//
// Copyright (c) 2020 nacamar GmbH - Ybrid®, a Hybrid Dynamic Live Audio Technology
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

class UseAudioPlayerTests: XCTestCase {

    override func setUpWithError() throws {
        // Log additional debug information in this tests
        Logger.verbose = true
    }
 
    // of course you may choose your own radio station here
    let url = URL.init(string: "https://swr-swr3.cast.ybrid.io/swr/swr3/ybrid")!
   
    /*
    Let the player play your radio.
    
    You should hear sound. Probably stop does not sound nice.
     
    Player actions (play and stop) operate asynchronously.
    Stop could need a second to clean up.
    */
    func test01_PlaySomeSeconds() {
        let player = AudioPlayer(mediaUrl: url, listener: nil)
        player.play()
        sleep(6)
        player.stop() // If the process is killed without stop()
        sleep(1) // or immediately after stop you may hear crackling.
    }

    /*
     Let the player play your radio and ensure expected playback states.

     Connecting and setting up depends on the infrastructure.
     In this test we assume it takes no longer than 3 seconds.
     */
    func test02_PlayerStates() {
        let player = AudioPlayer(mediaUrl: url, listener: nil)
        XCTAssertEqual(player.state, PlaybackState.stopped)
        player.play()
        XCTAssertEqual(player.state, PlaybackState.buffering)
        sleep(3)
        XCTAssertEqual(player.state, PlaybackState.playing)
        player.stop()
        XCTAssertEqual(player.state, PlaybackState.playing)
        sleep(1)
        XCTAssertEqual(player.state, PlaybackState.stopped)
    }

    /*
     Use your own radio player listener to be called back.
     Filter console output by '-- ' and watch.

     Make sure the listener stays alive until it recieves stateChanged to '.stopped'.
     */
    let playerListener = TestAudioPlayerListener()
    func test03_ListenToPlayer() {
        let player = AudioPlayer(mediaUrl: url, listener: playerListener)
        player.play()
        sleep(3)
        player.stop()
        sleep(1) // if not, the player listener may be gone to early
    }

    /*
     You want to see a problem?
     Filter the console output by '-- '
     */
    func test04_ErrorWithPlayer() {
        let badUrl = URL.init(string: "https://swr-swr3.cast.io/bad/url")!
        let player = AudioPlayer(mediaUrl: badUrl, listener: playerListener)
        player.play()
        XCTAssertEqual(player.state, PlaybackState.buffering)
        sleep(1)
        XCTAssertEqual(player.state, PlaybackState.stopped)
    }

    
    /*
     The audio codec opus is supported
     */
    func test05_PlayOpus() {
        let opusUrl = URL.init(string: "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")!
        let player = AudioPlayer(mediaUrl: opusUrl, listener: playerListener)
        player.play()
        sleep(6)
        player.stop()
        sleep(1)
    }
    
    /*
     HttpSessions on urls that offer "expected content length != -1"
     are identified as on demand files. They can be paused.
     Remember, all actions are asynchronous. So assertions are 1 second later.
     */
    func test06_OnDemandPlayPausePlayPauseStop() {
        let opusUrl = URL.init(string: "https://github.com/ybrid/test-files/blob/main/mpeg-audio/music/organ.mp3?raw=true")!
        let player = AudioPlayer(mediaUrl: opusUrl, listener: playerListener)
        XCTAssertFalse(player.canPause)
        player.play()
        XCTAssertEqual(player.state, PlaybackState.buffering)
        sleep(3)
        XCTAssertTrue(player.canPause)
        XCTAssertEqual(player.state, PlaybackState.playing)
        player.pause()
        sleep(1)
        XCTAssertEqual(player.state, PlaybackState.pausing)
        player.play()
        sleep(1)
        XCTAssertEqual(player.state, PlaybackState.playing)
        player.pause()
        sleep(1)
        XCTAssertEqual(player.state, PlaybackState.pausing)
        player.stop()
        sleep(1)
        XCTAssertEqual(player.state, PlaybackState.stopped)
    }
}

