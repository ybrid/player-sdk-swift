//
// PlayingEdgeCasesTests.swift
// player-sdk-swiftTests
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
    
    func test00_LoggerVerboseDefault() {
        XCTAssertFalse(Logger.verbose)
    }
    
    let maxSecondsWait = 3
    
    // MARK: abort playing mp3
        
    func testAbortMp3_until100msAfterConnect_CleanedUp() throws {
        Logger.verbose = true
        var interval:TimeInterval = 0.000
        repeat {
            let aborting = playMp3AndAbort(afterConnect:interval)
            
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
        var interval:TimeInterval = 1
        repeat {
            let aborting = playMp3AndAbort(afterConnect:interval)
            
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
        repeat {
            let aborting = playOpusAndAbort(afterConnect:interval)
            
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
        var interval:TimeInterval = 0.010
        repeat {
            let aborting = playOpusAndAbort(afterConnect:interval)
            
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
    
    private func playOpusAndAbort(afterConnect:TimeInterval) -> AbortingListener {
        let url = URL.init(string: "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")!
        return playAndAbort(url, afterConnect: afterConnect)
    }
    
    private func playMp3AndAbort(afterConnect:TimeInterval) -> AbortingListener {
        let url = URL.init(string: "https://swr-swr3.cast.ybrid.io/swr/swr3/ybrid")!
        return playAndAbort(url, afterConnect: afterConnect)
    }

    
    private func playAndAbort(_ url:URL, afterConnect:TimeInterval) -> AbortingListener {
        let abortingListener = AbortingListener(afterConnect:afterConnect)
        let player = AudioPlayer(mediaUrl: url, listener: abortingListener)
        abortingListener.player = player
        player.play()
        return abortingListener
    }
}

class AbortingListener : AudioPlayerListener  {
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
    
    func durationConnected(_ seconds: TimeInterval?) {
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
    
    func durationReadyToPlay(_ seconds: TimeInterval?) {
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
    
    func stateChanged(_ state: PlaybackState) {
        Logger.testing.notice("-- player is \(state)")
    }
    func displayTitleChanged(_ title: String?) {
        Logger.testing.notice("-- combined display title is \(title ?? "(nil)")")
    }
    func currentProblem(_ text: String?) {
        Logger.testing.notice("-- problem is \(text ?? "(nil)")")
        problemCount += 1
    }
    func playingSince(_ seconds: TimeInterval?) {
        if let duration = seconds {
            Logger.testing.notice("-- playing for \(duration.S) seconds ")
        } else {
            Logger.testing.notice("-- no playing duration ")
        }
    }
    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {
        if let bufferLength = currentSeconds {
            Logger.testing.notice("-- currently buffered \(bufferLength.S) seconds of audio")
        }
    }
}

extension PlaybackEngine {
    func cleanedUp() -> Bool {
        let noScheduling = playbackBuffer?.playingSince == nil
        let notPlaying = !playerNode.isPlaying && !engine.isRunning
        return timer == nil && noScheduling && notPlaying
    }
}


