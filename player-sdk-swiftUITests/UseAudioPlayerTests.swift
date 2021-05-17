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
        
        playerListener.reset()
    }
 
    // of course you may choose your own radio station here
    let myEndpoint = MediaEndpoint(mediaUri:  "https://swr-swr3.cast.ybrid.io/swr/swr3/ybrid")
   
    // see tests using the listener
    let playerListener = TestAudioPlayerListener()
    
    /*
    Let the player play your radio.
    
    You should hear sound. Probably stop does not sound nice.
     
    Player actions (play and stop) operate asynchronously.
    Stop could need a second to clean up.
    */
    func test01_PlaySomeSeconds() {
        guard let player = AudioPlayer.open(for: myEndpoint, listener: nil) else {
            XCTFail("no player, something went wrong"); return
        }
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
        guard let player = AudioPlayer.open(for: myEndpoint, listener: nil) else {
            XCTFail("no player, something went wrong"); return
        }
        XCTAssertEqual(player.state, PlaybackState.stopped)
        player.play()
        XCTAssertEqual(player.state, PlaybackState.buffering)
        sleep(5)
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

    func test03_ListenToPlayer() {
        guard let player = AudioPlayer.open(for: myEndpoint, listener: playerListener) else {
            XCTFail("no player, something went wrong"); return
        }
        player.play()
        sleep(3)
        player.stop()
        sleep(1) // if not, the player listener may be gone to early
    }

    /*
     You want to see a problem?
     Filter the console output by '-- '
     
     listener.error lets you see all errors, warnings and notifications
     */
    func test04_ErrorWithPlayer() {

        let badEndpoint = MediaEndpoint(mediaUri:  "https://swr-swr3.cast.io/bad/url")
        let player = AudioPlayer.open(for: badEndpoint, listener: playerListener)
        XCTAssertNil(player, "no player expected")
        
        XCTAssertEqual(playerListener.errors.count, 1)
        guard let lastError = playerListener.errors.last else {
            return
        }
        XCTAssertNotEqual(0, lastError.code) // error occured
        XCTAssertNotEqual(0, lastError.osstatus)
        XCTAssertEqual(603, lastError.code) // ErrorKind.serverError
        XCTAssertEqual(-1003, lastError.osstatus) // host not found
    }

    
    /*
     The audio codec opus is supported
     */
    func test05_PlayOpus() {
        let opusEndpoint = MediaEndpoint(mediaUri: "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")
        guard let player = AudioPlayer.open(for: opusEndpoint, listener: playerListener) else {
            XCTFail("no player. Something went wrong"); return
        }
        player.play()
        sleep(6)
        player.stop()
        sleep(1)
    }
    
    /*
     HttpSessions on urls that offer "expected content length != -1"
     are identified as on demand files. They can be paused.
     Remember, all actions are asynchronous. So assertions in this test are delayed.
     */
    func test06_OnDemandPlayPausePlayPauseStop() {
        let onDemandEndpoint = MediaEndpoint(mediaUri:  "https://github.com/ybrid/test-files/blob/main/mpeg-audio/music/organ.mp3?raw=true")
        guard let player = AudioPlayer.open(for: onDemandEndpoint, listener: playerListener) else {
            XCTFail("no player. Something went wrong"); return
        }
        XCTAssertFalse(player.canPause)
        player.play()
        XCTAssertEqual(player.state, PlaybackState.buffering)
        sleep(5)
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
    
    
    /*
     listener.metadataChanged is called when metadata changes. In the beginning of streaming
     there ist always a change comared to nothing.
     */
    func test07_ListenToMetadata() {

        guard let player = AudioPlayer.open(for: myEndpoint, listener: playerListener) else {
            XCTFail("no player. Something went wrong"); return
        }
        player.play()
        sleep(3)
        player.stop()
        sleep(1)
        
        XCTAssertGreaterThan(playerListener.metadatas.count, 0)
        guard playerListener.metadatas.count > 0 else {
            XCTFail("expected at least one metadata called"); return
        }
        let metadata = playerListener.metadatas[0]
        XCTAssertNotNil(metadata.current?.displayTitle)
        
    }
}

