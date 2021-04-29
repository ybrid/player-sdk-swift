//
// AbortBufferingTests.swift
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
@testable import YbridPlayerSDK

class AbortBufferingTests: XCTestCase {
    
    var session:MediaSession?
    
    
    override func tearDownWithError() throws {
        session?.close()
    }
    
    func test00_LoggerVerboseDefault() {
        XCTAssertFalse(Logger.verbose)
    }
    
    let maxSecondsWait = 3
    
    // MARK: abort playing mp3
        
    func testAbortMp3_until100msAfterConnect_CleanedUp() throws {
        Logger.verbose = true
        session = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/swr3/mp3/mid").createSession()
        
        var interval:TimeInterval = 0.000
        repeat {
            let aborting = playAndAbort(session!, afterConnect:interval)
            
            var cycle = 0
            var state:PlaybackState?
            repeat {
                sleep(1)
                state = aborting.player?.state
                cycle += 1
                Logger.testing.notice("-- \(state!) after \(cycle) seconds")
            } while PlaybackState.stopped != state && cycle <= maxSecondsWait
            
            let played = aborting.hasPlayed ? "played" : "not played"
            Logger.testing.notice("-- aborted \(interval.S) after connect: \(played), \(state!) after \(cycle) seconds, \(aborting.problemCount) errors occured, \(aborting.cleanedUp)")
            
            XCTAssertEqual(PlaybackState.stopped, state, "-- \(interval.S) after connect: \(state!) after \(cycle) seconds")
            XCTAssertTrue(cycle <= maxSecondsWait, "-- \(interval.S) after connect: took \(cycle) seconds")
            
            XCTAssertEqual(0, aborting.problemCount)
            XCTAssertTrue(aborting.cleanedUp,"-- \(interval.S) after connect: not cleaned up after \(cycle) seconds")
            
            interval += 0.005
        } while interval <= 0.101
    }

    func testAbortMp3_until1sAfterConnect_CleanedUp() throws {
        Logger.verbose = true
        session = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/swr3/mp3/mid").createSession()

        var interval:TimeInterval = 0.010
        repeat {
            let aborting = playAndAbort(session!, afterConnect:interval)
            
            var cycle = 0
            var state:PlaybackState?
            repeat {
                sleep(1)
                state = aborting.player?.state
                cycle += 1
                Logger.testing.notice("-- \(state!) after \(cycle) seconds")
            } while PlaybackState.stopped != state && cycle <= maxSecondsWait
            
            let played = aborting.hasPlayed ? "played" : "not played"
            Logger.testing.notice("-- aborted \(interval.S) after connect: \(played), \(state!) after \(cycle) seconds, \(aborting.problemCount) errors occured, \(aborting.cleanedUp)")
            
            XCTAssertEqual(PlaybackState.stopped, state, "-- \(interval.S) after connect: \(state!) after \(cycle) seconds")
            XCTAssertTrue(cycle <= maxSecondsWait, "-- \(interval.S) after connect: took \(cycle) seconds")
            
            XCTAssertEqual(0, aborting.problemCount)
            XCTAssertTrue(aborting.cleanedUp,"-- \(interval.S) after connect: not cleaned up after \(cycle) seconds")
            
            interval += 0.050
        } while interval <= 1
    }

    
    // MARK: abort playing opus
    
    
    func testAbortOpus_until100msAfterConnect_CleanedUp() throws {
        var interval:TimeInterval = 0.000
        session = MediaEndpoint(mediaUri: "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus").createSession()
       
        repeat {
            let aborting = playAndAbort(session!, afterConnect:interval)
            
            var cycle = 0
            var state:PlaybackState?
            repeat {
                sleep(1)
                state = aborting.player?.state
                cycle += 1
            } while PlaybackState.stopped != state && cycle <= maxSecondsWait
            
            let played = aborting.hasPlayed ? "played" : "not played"
            Logger.testing.notice("-- aborted \(interval.S) after connect: \(played), \(state!) after \(cycle) seconds, \(aborting.problemCount) errors occured, \(aborting.cleanedUp)")
            
            XCTAssertEqual(PlaybackState.stopped, state, "-- \(interval.S) after connect: \(state!) after \(cycle) seconds")
            XCTAssertTrue(cycle <= maxSecondsWait, "-- \(interval.S) after connect: took \(cycle) seconds")
            
            XCTAssertEqual(0, aborting.problemCount)
            XCTAssertTrue(aborting.cleanedUp,"-- \(interval.S) after connect: not cleaned up after \(cycle) seconds")
            
            interval += 0.005
        } while interval <= 0.101
    }

    func testAbortOpus_until1sAfterConnect_CleanedUp() throws {
        Logger.verbose = true
        session = MediaEndpoint(mediaUri: "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus").createSession()
        var interval:TimeInterval = 0.010
        repeat {
            let aborting = playAndAbort(session!, afterConnect:interval)
            
            var cycle = 0
            var state:PlaybackState?
            repeat {
                sleep(1)
                state = aborting.player?.state
                cycle += 1
                Logger.testing.notice("-- \(state!) after \(cycle) seconds")
            } while PlaybackState.stopped != state && cycle <= maxSecondsWait
            
            let played = aborting.hasPlayed ? "played" : "not played"
            Logger.testing.notice("-- aborted \(interval.S) after connect: \(played), \(state!) after \(cycle) seconds, \(aborting.problemCount) errors occured, \(aborting.cleanedUp)")
            
            XCTAssertEqual(PlaybackState.stopped, state, "-- \(interval.S) after connect: \(state!) after \(cycle) seconds")
            XCTAssertTrue(cycle <= maxSecondsWait, "-- \(interval.S) after connect: took \(cycle) seconds")
            
            XCTAssertEqual(0, aborting.problemCount)
            XCTAssertTrue(aborting.cleanedUp,"-- \(interval.S) after connect: not cleaned up after \(cycle) seconds")
            
            interval += 0.050
        } while interval <= 1
    }

    // MARK: helpers
        
    private func playAndAbort(_ session:MediaSession, afterConnect:TimeInterval) -> AbortingListener {
        let abortingListener = AbortingListener(afterConnect:afterConnect)
        let player = AudioPlayer(session: session, listener: abortingListener)
        abortingListener.player = player
        player.play()
        return abortingListener
    }
}

class AbortingListener : AbstractAudioPlayerListener  {
    let afterConnect:TimeInterval
    
    var player:AudioPlayer?
    private let testQueue = DispatchQueue(label: "io.ybrid.player-sdk-tests")
    
    var hasPlayed = false
    var problemCount = 0
    
    var cleanedUp:Bool {
        guard let pbEngine = player?.playback as! PlaybackEngine? else {
            return true
        }
        return pbEngine.cleanedUp()
    }
    
    init(afterConnect: TimeInterval) {
        self.afterConnect = afterConnect
    }
    
    private func abort() {
        Logger.testing.notice("-- aborting player")
        player?.stop()
    }
    
    override func durationConnected(_ seconds: TimeInterval?) {
        Logger.testing.notice("-- recieved first data from url after \(seconds!.S) seconds ")
        guard let state = player?.state else {
            XCTFail("durationConnected -- player without state.")
            return
        }
        XCTAssertEqual(state, PlaybackState.buffering, "-- state should not be \(state)")
        
        testQueue.asyncAfter(deadline: .now() + afterConnect) {
            self.abort()
        }
    }
    
    override func durationReadyToPlay(_ seconds: TimeInterval?) {
        hasPlayed = true
        
        guard let duration = seconds else {
            Logger.testing.error("-- durationReadyToPlay is nil")
            return
        }
        guard let state = player?.state else {
            XCTFail("-- player without state.")
            return
        }
        
        Logger.testing.notice("-- state is \(state)")
        switch state {
        case .stopped:
            XCTFail("-- should not begin playing.")
        case .playing:
            XCTFail("-- should not play already.")
        default:
            Logger.testing.notice("-- durationReady took \(duration.S) seconds ")
        }
    }
}

extension PlaybackEngine {
    func cleanedUp() -> Bool {
        let noTimer = timer == nil
        XCTAssertTrue(noTimer, "timer should be gone")
        let noScheduling = playbackBuffer?.playingSince == nil
        XCTAssertTrue(noScheduling, "playing since should be nil")
        let notPlaying = !playerNode.isPlaying
        XCTAssertTrue(notPlaying, "player node should not be playing")
        let notRunning = !engine.isRunning
        XCTAssertTrue(notRunning, "engine should not be running")
        return noTimer && noScheduling && notPlaying && notRunning
    }
}


