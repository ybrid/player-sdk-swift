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
    
    override func tearDownWithError() throws {
    }
    
    func test00_LoggerVerboseDefault() {
        XCTAssertFalse(Logger.verbose)
    }
    
    let maxSecondsWait = 4
    
    // MARK: abort playing mp3
        
    func testAbortMp3_until100msAfterConnect_CleanedUp() throws {
        Logger.verbose = true
        let endpoint = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/swr3/mp3/mid")
        let abortingListener = AbortingListener()
        guard var player = AudioPlayer.open(for: endpoint, listener: abortingListener) else {
            XCTFail(); return
        }
        abortingListener.player = player
        
        var interval:TimeInterval = 0.000
        repeat {
            abortingListener.prepare(interval)
            player.play()
            
            let cycle = wait(player, until: .stopped, maxSeconds: maxSecondsWait)
            let failed = reportAndCheck(interval, cycle, abortingListener)
            
            if failed {
                player.close()
                player = AudioPlayer.open(for: endpoint, listener: abortingListener)!
                abortingListener.player = player
            }
            
            interval += 0.005
        } while interval <= 0.101
    }

    
    private func reportAndCheck(_ interval:TimeInterval, _ seconds:Int, _ listener:AbortingListener) -> Bool {
        
        let state = (listener.player?.state)!
        Logger.testing.notice("-- \(state) after \(seconds) seconds")
        
        let played = listener.hasPlayed ? "played" : "not played"
        Logger.testing.notice("-- aborted \(interval.S) after connect: \(played), \(state) after \(seconds) seconds, \(listener.problemCount) errors occured, \(listener.cleanedUp)")
        
        XCTAssertEqual(0, listener.problemCount)
        XCTAssertTrue(listener.cleanedUp,"-- \(interval.S) after connect: not cleaned up after \(seconds) seconds")
        
        XCTAssertEqual(PlaybackState.stopped, state, "-- \(interval.S) after connect: \(state) after \(seconds) seconds")
        XCTAssertTrue(seconds <= maxSecondsWait, "-- \(interval.S) after connect: took \(seconds) seconds")
        
        return seconds > maxSecondsWait
    }
    
    func testAbortMp3_until1sAfterConnect_CleanedUp() throws {
        Logger.verbose = true
        let endpoint = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/swr3/mp3/mid")
        let abortingListener = AbortingListener()
        guard var player = AudioPlayer.open(for: endpoint, listener: abortingListener) else {
            XCTFail(); return
        }
        abortingListener.player = player
        
        var interval:TimeInterval = 0.010
        repeat {
            abortingListener.prepare(interval)
            player.play()

            let cycle = wait(player, until: .stopped, maxSeconds: maxSecondsWait)
            let failed = reportAndCheck(interval, cycle, abortingListener)
            
            if failed {
                player.close()
                player = AudioPlayer.open(for: endpoint, listener: abortingListener)!
                abortingListener.player = player
            }
            
            interval += 0.050
        } while interval <= 1
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
    
    // MARK: abort playing opus
    
    func testAbortOpus_until100msAfterConnect_CleanedUp() throws {
        let endpoint = MediaEndpoint(mediaUri: "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")
        let abortingListener = AbortingListener()
        guard var player = AudioPlayer.open(for: endpoint, listener: abortingListener) else {
            XCTFail(); return
        }
        abortingListener.player = player
        
        var interval:TimeInterval = 0.000
        repeat {
            abortingListener.prepare(interval)
            player.play()

            let cycle = wait(player, until: .stopped, maxSeconds: maxSecondsWait)
            let failed = reportAndCheck(interval, cycle, abortingListener)
            
            if failed {
                player.close()
                player = AudioPlayer.open(for: endpoint, listener: abortingListener)!
                abortingListener.player = player
            }
            
            interval += 0.005
        } while interval <= 0.101
    }

    func testAbortOpus_until1sAfterConnect_CleanedUp() throws {
        Logger.verbose = true
        let endpoint = MediaEndpoint(mediaUri: "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")
        let aborting = AbortingListener()
        guard var player = AudioPlayer.open(for: endpoint, listener: aborting) else {
            XCTFail(); return
        }
        aborting.player = player
        
        var interval:TimeInterval = 0.010
        repeat {
            aborting.prepare(interval)
            player.play()

            let cycle = wait(player, until: .stopped, maxSeconds: maxSecondsWait)
            let failed = reportAndCheck(interval, cycle, aborting)
            
            if failed {
                player.close()
                player = AudioPlayer.open(for: endpoint, listener: aborting)!
                aborting.player = player
            }
            
            interval += 0.050
        } while interval <= 1
    }
}

class AbortingListener : AbstractAudioPlayerListener  {
    var afterConnect:TimeInterval = -1.0
    
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
    
    func prepare(_ abortAfterConnect:TimeInterval) {
        
        hasPlayed = false
        problemCount = 0
        afterConnect = abortAfterConnect
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


