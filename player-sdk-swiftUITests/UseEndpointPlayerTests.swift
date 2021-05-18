//
// UseEndpointPlayerTests.swift
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

class UseEndpointPlayerTests: XCTestCase {
    

    let playerListener = TestAudioPlayerListener()
    override func setUpWithError() throws {
        // Log additional debug information in this tests
        Logger.verbose = true
        playerListener.reset()
    }
    
    var player:PlaybackControl?
    override func tearDownWithError() throws {
        player?.close()
        player = nil
    }
    
    func test01_Ybrid_PlaySomeSeconds() throws {
        try AudioPlayer.create(for: ybridDemoEndpoint) { [self]
            (playbackControl) in
            XCTAssertEqual(MediaProtocol.ybridV2, playbackControl.mediaProtocol)
            player = playbackControl
            playbackControl.play()
            wait(playbackControl, until: .buffering, maxSeconds: 1)
        }
        wait(until: .playing, maxSeconds: 10)
        sleep(3)
        player?.stop()
        wait(until: .stopped, maxSeconds: 2)
    }
    
 

    func test02_Icy_PlaySomeSeconds() throws {

        try AudioPlayer.create(for: icecastHr2Endpoint) { [self]
            (playbackControl) in
            XCTAssertEqual(MediaProtocol.icy, playbackControl.mediaProtocol)
            player = playbackControl
            playbackControl.play()
            wait(playbackControl, until: .buffering, maxSeconds: 1)
        }
        wait(until: .playing, maxSeconds: 10)
        sleep(3)
        player?.stop()
        wait(until: .stopped, maxSeconds: 2)
    }

    func test04_Icy_Opus_PlaySomeSeconds() throws {
        
        try AudioPlayer.create(for: opusDlfEndpoint) { [self]
            (playbackControl) in
            player = playbackControl
            XCTAssertEqual(MediaProtocol.icy, playbackControl.mediaProtocol)
            playbackControl.play()
            wait(playbackControl, until: .buffering, maxSeconds: 1)
        }
        wait(until: .playing, maxSeconds: 10)
        sleep(3)
        player?.stop()
        wait(until: .stopped, maxSeconds: 2)
    }

    
    func test05_Icy_OnDemand_PlayPausePlay() throws {

        try AudioPlayer.create(for: onDemandMp3Endpoint) { [self]
            (playbackControl) in
            XCTAssertEqual(MediaProtocol.icy, playbackControl.mediaProtocol)
            player = playbackControl
            playbackControl.play()
            wait(playbackControl, until: .buffering, maxSeconds: 1)
        }
        wait(until: .playing, maxSeconds: 10)
        sleep(3)
        player?.pause()
        wait(until: .pausing, maxSeconds: 2)
        player?.play()
        wait(until: .playing, maxSeconds: 5)
        sleep(1)
        player?.stop()
        wait(until: .stopped, maxSeconds: 2)
    }
    
    
    func test02_WrongUri_PlayStops() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/wronguri")
        try AudioPlayer.create(for: endpoint, listener: playerListener) { [self]
            (playbackControl) in
            XCTAssertEqual(MediaProtocol.icy, playbackControl.mediaProtocol)
            player = playbackControl
            playbackControl.play()
            wait(playbackControl, until: .buffering, maxSeconds: 1)
        }
        wait(until: .buffering, maxSeconds: 3)
        wait(until: .stopped, maxSeconds: 5)
        XCTAssertEqual(1, playerListener.errors.count)
        let lastError = playerListener.errors.last!
        XCTAssertNotEqual(0, lastError.code)
        XCTAssertNotEqual(0, lastError.osstatus) // cannotProcessMimeType, cannot process text/plain with filename wrongurl.txt
    }

    
    func test06_Error_WithPlayer_cannotProcessMimeType() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://cast.ybrid.io/bad/url")
        do {
        try AudioPlayer.create(for: endpoint, listener: playerListener) { [self]
            (playbackControl) in
            XCTAssertEqual(.icy, playbackControl.mediaProtocol)
            self.player = playbackControl
            playbackControl.play()
            wait(playbackControl, until: .buffering, maxSeconds: 1)
        }
        wait(until: .buffering, maxSeconds: 5)
        wait(until: .stopped, maxSeconds: 15)
            
        XCTAssertEqual(1, playerListener.errors.count)
        let error = playerListener.errors[0]
            XCTAssertNotEqual(0, error.code) // error occured
            XCTAssertEqual(302, error.code) // ErrorKind.cannotProcessMimeType
        } catch {
            XCTFail("should not be called, error in loading"); return
        }
    }
    
    func test06_Error_NoPlayer_HostNotFound() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://swr-swr3.cast.io/bad/url")
        do {
        try AudioPlayer.create(for: endpoint, listener: playerListener) { [self]
            (playbackControl) in
            XCTFail("should not be called, we get no player")
        }
        sleep(5)
        XCTAssertNil(player)

        XCTAssertEqual(1, playerListener.errors.count)
        let error = playerListener.errors[0]
        XCTAssertNotEqual(0, error.code)
        XCTAssertEqual(-1003, error.osstatus) //  OSStatus=-1003, host not found
        } catch {
            guard let sessionError = error as? AudioPlayerError else {
                XCTFail("must be an audio error"); return
            }
            XCTAssertNotEqual(0, sessionError.code)
            XCTAssertEqual(603, sessionError.code) // ErrorKind.serverError
            XCTAssertEqual(-1003, sessionError.osstatus) // host not found
        }
    }
    
    

 
    // MARK: helper function
    private func wait(until:PlaybackState, maxSeconds:Int) {
        var seconds = 0
        while player == nil && seconds <= maxSeconds {
            sleep(1)
            seconds += 1
        }
        while player?.state == nil || (player?.state != until && seconds <= maxSeconds) {
                sleep(1)
                seconds += 1
            }
        print("took \(seconds) second\(seconds > 1 ? "s" : "") until \(player?.state)")
            XCTAssertEqual(until, player?.state)
    }
    
    
    private func wait(_ playback:PlaybackControl, until:PlaybackState, maxSeconds:Int) {

        var seconds = 0
        while playback.state != until && seconds <= maxSeconds {
            sleep(1)
            seconds += 1
        }
        print("took \(seconds) second\(seconds > 1 ? "s" : "") until \(playback.state)")
        XCTAssertEqual(until, playback.state)
    }

}
