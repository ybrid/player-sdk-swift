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

extension Logger {
    static let testing: Logger = Logger(category: "testing")
}

class AbortBufferingTests: XCTestCase {
    
    override func tearDownWithError() throws {
        sleep(5)
    }
    
    func test00_LoggerVerboseDefault() {
        XCTAssertFalse(Logger.verbose)
    }
    
    let maxSecondsWait = 4
    
    // MARK: abort playing mp3

    func test01_AbortMp3_until200msAfterConnectCleanedUp_failsSometimesFrom25msTo35ms() throws {
        Logger.verbose = false

        try executeYbrid(endpoint: ybridSwr3Endpoint, startInterval: 0.000, endInterval: 0.121, increaseInterval: 0.005, increaseInCaseOfFailure: 0.001)
    }

    func test02_AbortMp3_until1sAfterConnectCleanedUp_ok() throws {

        try executeYbrid(endpoint: ybridSwr3Endpoint, startInterval: 0.010, endInterval: 1.001, increaseInterval: 0.050, increaseInCaseOfFailure: 0.011)
    }
    
    func test03_AbortOpus_0until100msAfterConnectCleanedUp_failsSometimesFrom15To40ms() throws {

        let failed = try executeIcy(endpoint: opusDlfEndpoint, startInterval: 0.000, endInterval: 0.121, increaseInterval: 0.005, increaseInCaseOfFailure: 0.001)
        Logger.testing.notice("\(failed) failed abortion tests")
    }
    
    func test04_AbortOpus_until1sAfterConnect_CleanedUp_ok() throws {

        let failed = try executeIcy(endpoint: opusDlfEndpoint, startInterval: 0.010, endInterval: 1.001, increaseInterval: 0.050, increaseInCaseOfFailure: 0.011)
        Logger.testing.notice("\(failed) failed abortion tests")
    }
    
    func executeYbrid(endpoint: MediaEndpoint, startInterval:TimeInterval, endInterval:TimeInterval, increaseInterval:TimeInterval, increaseInCaseOfFailure:TimeInterval ) throws {
        var interval = startInterval
        newAfterFailed: repeat {
            let semaphore = DispatchSemaphore(value: 0)
            let abortingListener = CtrlStopListener()
            var passed = true
            try AudioPlayer.open(for: endpoint, listener: abortingListener, playbackControl: nil, ybridControl: { [self] (ybridCtrl) in
                    abortingListener.control = ybridCtrl
                    passed = repeatToggling(abortingListener: abortingListener, interval: &interval, increaseInterval: increaseInterval, endInterval: endInterval)
                    if !passed { ybridCtrl.close(); sleep(3) }
                    semaphore.signal()
            })
            _ = semaphore.wait(timeout: .distantFuture)
            if passed {
                Logger.testing.notice("passed stopping after \(interval.S)")
                interval += increaseInterval
            } else {
                Logger.testing.error("failed stopping after \(interval.S)")
                interval += increaseInCaseOfFailure
            }
        } while interval <= endInterval
    }
    
    func executeIcy(endpoint: MediaEndpoint, startInterval:TimeInterval, endInterval:TimeInterval, increaseInterval:TimeInterval, increaseInCaseOfFailure:TimeInterval ) throws -> Int { // failedCount
        var failedCount = 0
        var interval = startInterval
        newAfterFailed: repeat {
            let semaphore = DispatchSemaphore(value: 0)
            let abortingListener = CtrlStopListener()
            var passed = true
            try AudioPlayer.open(for: endpoint, listener: abortingListener, playbackControl: { [self] (control) in
                    abortingListener.control = control
                    passed = repeatToggling(abortingListener: abortingListener, interval: &interval, increaseInterval: increaseInterval, endInterval: endInterval)
                    if !passed { control.close(); sleep(3) }
                    semaphore.signal()
            })
            _ = semaphore.wait(timeout: .distantFuture)
            if passed {
                Logger.testing.notice("passed stopping after \(interval.S)")
                interval += increaseInterval
            } else {
                failedCount += 1
                Logger.testing.error("failed stopping after \(interval.S)")
                interval += increaseInCaseOfFailure
            }
        } while interval <= endInterval
        return failedCount
    }
 
    private func repeatToggling(abortingListener:CtrlStopListener, interval: inout TimeInterval, increaseInterval:TimeInterval, endInterval:TimeInterval) -> Bool { // passed --> true
        var passed = true
        let control = abortingListener.control!
        toggling: repeat {
            abortingListener.prepare(interval)
            control.play()
            let cycle = wait(control, until: .stopped, maxSeconds: maxSecondsWait)
            passed = checkAndReport(interval, cycle, abortingListener)
            if !passed {
                break toggling
            }
            interval += increaseInterval
        } while passed && interval <= endInterval
        return passed
    }
    
    private func checkAndReport(_ interval:TimeInterval, _ seconds:Int, _ listener:CtrlStopListener) -> Bool { // true -> passed
        
        let state = (listener.control?.state)!
        
        Logger.testing.notice("-- aborted \(interval.S) after connect:\(listener.hasPlayed ? "":" not") played, \(state) after \(seconds) seconds, \(listener.problemCount) errors occured,\(listener.cleanedUp ? "":" not") cleaned up")
        
        XCTAssertEqual(0, listener.problemCount)
        XCTAssertTrue(listener.cleanedUp,"\(interval.S) after connect: not cleaned up after \(seconds) seconds")
        
        XCTAssertTrue(seconds <= maxSecondsWait, "aborted \(interval.S) after connect.  \(state) after \(seconds) seconds is unexpected")
        
        return seconds <= maxSecondsWait && state == PlaybackState.stopped
            && listener.problemCount == 0 && listener.cleanedUp
    }

    private func wait(_ player:AudioPlayer, until:PlaybackState, maxSeconds:Int) -> Int {
        wait(player as PlaybackControl, until: until, maxSeconds: maxSeconds)
    }
    private func wait(_ control:YbridControl, until:PlaybackState, maxSeconds:Int) -> Int {
        wait(control as PlaybackControl, until: until, maxSeconds: maxSeconds)
    }
    private func wait(_ player:PlaybackControl, until:PlaybackState, maxSeconds:Int) -> Int {
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


// MARK: abort playing

class CtrlStopListener: AudioPlayerListener  {
    func stateChanged(_ state: PlaybackState) {    }
    
    func metadataChanged(_ metadata: Metadata) {    }
    
    func error(_ severity: ErrorSeverity, _ exception: AudioPlayerError) {    }

    func playingSince(_ seconds: TimeInterval?) {     }
    
    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {    }
    
    var afterConnect:TimeInterval = -1.0
    
    var control:PlaybackControl?
    private let testQueue = DispatchQueue(label: "io.ybrid.player.aborting")
    
    var hasPlayed = false
    var problemCount = 0
    
    var cleanedUp:Bool {
        guard let pbEngine = (control as? AudioPlayer)?.playback as? PlaybackEngine else {
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
        control?.stop()
    }
    
    func durationConnected(_ seconds: TimeInterval?) {
        Logger.testing.notice("-- recieved first data from url after \(seconds!.S) seconds ")
        guard let state = control?.state else {
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
        guard let state = control?.state else {
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


