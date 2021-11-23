//
// PlayerToggleStressTest.swift
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

class PlayerToggleStressTest: XCTestCase, AudioPlayerListener {
    
    var triggeredPlay:Int = 0
    var triggeredStop:Int = 0
    var triggeredPause:Int = 0
    
    var stepDuration:TimeInterval = 10
    var rangeFrom:TimeInterval = 1
    var rangeTo:TimeInterval = 3
    var restBetweenSteps:TimeInterval = 5
    var stepsDecrease = 10
    var finalRestDuration:TimeInterval = 60
    
    var testDuration:TimeInterval {
        return TimeInterval((stepDuration.us + restBetweenSteps.us) * stepsDecrease / 1_000_000) - restBetweenSteps
    }
    
    var player:AudioPlayer?
    
    var waitingQueue = DispatchQueue(label: "waiting")
    override func setUpWithError() throws {
        triggeredPlay = 0
        triggeredStop = 0
        
        Logger.testing.notice("------------------")
        Logger.testing.notice("-- start test of toggling play and stop")
        if Thread.isMainThread{
            Logger.testing.debug("-- executing set up in main thread")
        }else{
            Logger.testing.debug("-- executing set up in other thread")
        }
    }
    
    override func tearDownWithError() throws {
        if Thread.isMainThread{
            Logger.testing.debug("-- executing tear down in main thread")
        }else{
            Logger.testing.debug("-- executing tear down in other thread")
        }
        Logger.testing.notice("-- triggered play \(self.triggeredPlay), stop \(self.triggeredStop)")
        Logger.testing.notice("-- end of toggling play and stop")
        Logger.testing.notice("------------------")
        
        player?.close()
        Logger.testing.notice("-- final rest for \(finalRestDuration.S) ")
        _ = waitingQueue.sync { sleep(UInt32(finalRestDuration)) }
        Logger.testing.notice("------------------")
    }
    
    func test01_LiveMP3PlayStop() throws {
        player = AudioPlayer.openSync(for: icecastSwr3Endpoint, listener: self)
        
        stepDuration = 10
        rangeFrom = 1 /// on first step
        rangeTo = 3 /// on first step
        restBetweenSteps = 5
        stepsDecrease = 10
        
        self.execute()
    }
    
    func test02_LiveOpusPlayStop() throws {
        player = AudioPlayer.openSync(for: opusDlfEndpoint, listener: self)
        
        stepDuration = 10
        rangeFrom = 1 /// on first step
        rangeTo = 3 /// on first step
        restBetweenSteps = 5
        stepsDecrease = 10
        
        Logger.testing.notice("-- test will take ~\(testDuration.S)")
        Logger.testing.notice("-- final rest after test ~\(finalRestDuration.S)")
        
        self.execute()
    }

    func test03_OnDemandAACPlayPause() throws {
        player = AudioPlayer.openSync(for: aacHEv2Endpoint, listener: self)
        
        stepDuration = 10
        rangeFrom = 1 /// on first step
        rangeTo = 3 /// on first step
        restBetweenSteps = 5
        stepsDecrease = 10
        
        self.execute()
    }
    func execute() {
        if Thread.isMainThread{
            Logger.testing.debug("-- executing test in main thread")
        }else{
            Logger.testing.debug("-- executing test in other thread")
        }
        
        for step in 1...stepsDecrease {
            
            let nToggles = stepDuration.us / ( (rangeTo.us + rangeFrom.us) / 2)
            Logger.testing.notice("-- step \(step)/\(stepsDecrease): interval \(rangeFrom.S) ... \(rangeTo.S), toggling \(nToggles) times")
            
            for _ in 1...nToggles {
                let waiting = TimeInterval.random(in: self.rangeFrom...self.rangeTo)
                let action = self.toggle()
                switch action {
                case .play:
                    self.triggeredPlay += 1
                case .stop:
                    self.triggeredStop += 1
                case .pause:
                    self.triggeredPause += 1
                }
                Logger.testing.notice("-- \(action) \(waiting.S)")
                usleep(useconds_t(waiting.us))
            }
            
            if step != stepsDecrease {
                Logger.testing.notice("-- rest for \(restBetweenSteps.S) after step \(step)/\(stepsDecrease)")
                usleep(useconds_t(restBetweenSteps.us))
                
                rangeFrom = rangeFrom * 2 / 3
                rangeTo = rangeTo * 2 / 3
            }
        }
        
        if self.player?.state != .stopped {
            self.player?.stop()
            sleep(1)
        }
    }
    
    enum Action {
        case play
        case stop
        case pause
    }
    
    private func toggle() -> Action {
        guard let player = self.player else {fatalError()}
        if player.state == .stopped || player.state == .pausing {
            player.play()
            return Action.play
        } else {
            if player.canPause {
                player.pause()
                return Action.pause
            }
            player.stop()
            return Action.stop
        }
    }
    
    
    // MARK: radio player delegate
    
    func stateChanged(_ to: PlaybackState) {}
    func metadataChanged(_ metadata: Metadata) {}

    func error(_ severity:ErrorSeverity, _ exception: AudioPlayerError) {
        Logger.testing.notice("-- \(severity) is \(exception.localizedDescription)")
    }
    func playingSince(_ seconds: TimeInterval?) {
        if let since = seconds {
            Logger.testing.debug("-- + playing since \(since.S)")
        }
    }
    func durationConnected(_ seconds: TimeInterval?) {
        if let connected = seconds {
            Logger.testing.notice("-- + connected after \(connected.S)")
        }
    }
    func durationReadyToPlay(_ seconds: TimeInterval?) {
        if let ready = seconds {
            Logger.testing.notice("-- + ready after \(ready.S)")
        }
    }
    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {
        if let buffer = currentSeconds {
            Logger.testing.debug("-- + buffer \(buffer.S)")
        }
    }
    
}


