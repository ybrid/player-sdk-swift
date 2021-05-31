//
// UseAudioControlTests.swift
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

class UseContolsTests: XCTestCase {
    

    let playerListener = TestYbridPlayerListener()
    
    var semaphore:DispatchSemaphore?
    override func setUpWithError() throws {
        // Log additional debug information in this tests
        Logger.verbose = true
        playerListener.reset()
        semaphore = DispatchSemaphore(value: 0)
    }
    
    override func tearDownWithError() throws {}
    
    func test01_Ybrid_PlaySomeSeconds() throws {
        
        try AudioPlayer.open(for: ybridStageSwr3Endpoint, listener: nil,
               ybridControl: { [self] (ybridControl) in
                
                let offset = ybridControl.offsetToLiveS
                Logger.testing.notice("offset to live is \(offset.S)")
                XCTAssertLessThan(offset, -0.5)
                XCTAssertGreaterThan(offset, -5.0)
                
                ybridControl.play()
                wait(ybridControl, until: .playing, maxSeconds: 10)
                sleep(3)
                ybridControl.stop()
                wait(ybridControl, until: .stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
    }

    func test02_Icy_PlaySomeSeconds() throws {

        try AudioPlayer.open(for: icecastHr2Endpoint,
            playbackControl: { [self] (playback, mediaProtocol) in
            
                XCTAssertEqual(MediaProtocol.icy, mediaProtocol)
                
                playback.play()
                wait(playback, until: .playing, maxSeconds: 10)
                sleep(3)
                playback.stop()
                wait(playback, until: .stopped, maxSeconds: 2)
                
                semaphore?.signal()
           })
        _ = semaphore?.wait(timeout: .distantFuture)
    }

    func test04_Icy_Opus_PlaySomeSeconds() throws {
        
        try AudioPlayer.open(for: opusDlfEndpoint,
            playbackControl: { [self] (playback, mediaProtocol) in
                
                XCTAssertEqual(MediaProtocol.icy, mediaProtocol)
               
                playback.play()
                wait(playback, until: .playing, maxSeconds: 10)
                sleep(3)
                playback.stop()
                wait(playback, until: .stopped, maxSeconds: 2)
                
                semaphore?.signal()
           })
        _ = semaphore?.wait(timeout: .distantFuture)
    }

    
    func test05_Icy_OnDemand_PlayPausePlay() throws {

        try AudioPlayer.open(for: onDemandMp3Endpoint,
            playbackControl: { [self] (playback, mediaProtocol) in
                
                XCTAssertEqual(MediaProtocol.icy, mediaProtocol)
                XCTAssertFalse(playback.canPause)
                
                playback.play()
                wait(playback, until: .playing, maxSeconds: 10)
                XCTAssertTrue(playback.canPause)
                sleep(3)
                playback.pause()
                wait(playback, until: .pausing, maxSeconds: 2)
                playback.play()
                wait(playback, until: .playing, maxSeconds: 5)
                sleep(1)
                playback.stop()
                wait(playback, until: .stopped, maxSeconds: 2)
                
                semaphore?.signal()
            })
        _ = semaphore?.wait(timeout: .distantFuture)
    }
    
    func test06_AudioDataError_PlayStops() {
        let endpoint = MediaEndpoint(mediaUri: "https://cast.ybrid.io/bad/url")
        do {
            try AudioPlayer.open(for: endpoint, listener: playerListener,
                playbackControl: { [self] (playback, mediaProtocol) in

                    XCTAssertEqual(.icy, mediaProtocol)

                    playback.play()
                    wait(playback, until: .buffering, maxSeconds: 1)
                    wait(playback, until: .stopped, maxSeconds: 15)
                
                semaphore?.signal()
            })
        } catch {
            XCTFail("should not be called, error reading wrong data tyoe expected");
            semaphore?.signal(); return
        }
        _ = semaphore?.wait(timeout: .distantFuture)
            
        XCTAssertEqual(1, playerListener.errors.count)
        let error = playerListener.errors[0]
        XCTAssertTrue( error is AudioDataError, "expected AudioDataError but was \(error.localizedDescription)" )
        XCTAssertNotEqual(0, error.code) // error occured
        XCTAssertEqual(302, error.code) // ErrorKind.cannotProcessMimeType
    }
    
    func test07_ControllingError_NoPlayer() {
        let endpoint = MediaEndpoint(mediaUri: "https://swr-swr3.cast.io/bad/url")
        do {
            try AudioPlayer.open(for: endpoint, listener: playerListener,
               playbackControl: { [self] (playback, mediaProtocol) in
                
                    XCTFail("should not be called, we get no player")
                
                semaphore?.signal()
            })
        } catch {
            XCTAssertTrue( error is SessionError )
            guard let sessionError = error as? SessionError else {
                XCTFail("session error expected"); return
            }
            XCTAssertNotEqual(0, sessionError.code)
            XCTAssertEqual(603, sessionError.code) // ErrorKind.serverError
            XCTAssertEqual(-1003, sessionError.osstatus) // host not found
            
            semaphore?.signal()
        }
        _ = semaphore?.wait(timeout: .distantFuture)


        XCTAssertEqual(1, playerListener.errors.count)
        let error = playerListener.errors[0]
        XCTAssertNotEqual(0, error.code)
        XCTAssertEqual(-1003, error.osstatus) // host not found
    }


    // MARK: helper function
    private func wait(_ ybrid:YbridControl, until:PlaybackState, maxSeconds:Int) {
        wait(ybrid as PlaybackControl, until: until, maxSeconds: maxSeconds)
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
