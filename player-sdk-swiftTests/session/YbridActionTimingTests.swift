//
// YbridActionTimingTests.swift
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

class YbridActionTimingTests: XCTestCase {
    

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func test01_ReconnectSession_Demo_ok() throws {
        let semaphore = DispatchSemaphore(value: 0)
        let listener = TimingListener()

        try AudioPlayer.open(for: ybridDemoEndpoint, listener: listener,
             playbackControl: { (c) in
                return },
             ybridControl: { (ybridControl) in
                if let ybrid = ybridControl as? YbridAudioPlayer {
                    if let v2 = ybrid.session.mediaControl as? YbridV2Driver {
                        print("base uri is \(v2.baseUrl)")
                        let baseUrlOrig = v2.baseUrl
                        
                        // forcing to reconnect
                        do {
                            try v2.reconnect()
                        } catch {
                            Logger.session.error(error.localizedDescription)
                            XCTFail("should work, but \(error.localizedDescription)")
                        }
                        print("base uri is \(v2.baseUrl)")
                        let baseUrlReconnected = v2.baseUrl
                        XCTAssertEqual(baseUrlOrig, baseUrlReconnected)
 
                    
                        ybrid.play()
                        print("base uri is \(v2.baseUrl)")
                    }
                }
                sleep(4)
                ybridControl.close()
                semaphore.signal()
             })
        _ = semaphore.wait(timeout: .distantFuture)
        let errCount = listener.errors.count
        guard errCount == 0 else {
            XCTFail("recreating session should work")
            return
        }
    }
   
    func test02_DemoSwapItem() throws {
        let swapTook = try playAndSwapItem(ybridDemoEndpoint)
        XCTAssertLessThan(swapTook, 4, "swapping item should take less than 4s, took \(swapTook.S)")
      }
   
    func test02_AdDemoSwapItem() throws {
        let swapTook = try playAndSwapItem(ybridAdDemoEndpoint)
        XCTAssertLessThan(swapTook, 1, "not swapping item should take less than 1s, took \(swapTook.S)")
      }
    
    func test04_DemoSwapService() throws {
        let swapTook = try playAndSwapService(ybridDemoEndpoint, to: "ad-injection-demo")
        XCTAssertLessThan(swapTook, 4, "swapping service should take less than 4s, took \(swapTook.S)")
    }
    
    func test05_Swr3SwapService() throws {
        let swapTook = try playAndSwapService(ybridSwr3Endpoint, to: "swr-raka06")
        XCTAssertLessThan(swapTook, 4, "swapping service should take less than 4s, took \(swapTook.S)")
    }
    
    func test06_DemoSwapSwappedService_IcyTriggerInTime() throws {
        let swapTook = try playAndSwapSwappedService(ybridDemoEndpoint, first: "ad-injection-demo", second: "adaptive-demo")
        XCTAssertLessThan(swapTook, 4, "swapping service should take less than 4s, took \(swapTook.S)")
    }
    
    func test07_AdDemoSwapSwappedService_IcyTriggerInTime() throws {
        let swapTook = try playAndSwapSwappedService(ybridAdDemoEndpoint, first: "adaptive-demo", second: "ad-injection-demo")
        XCTAssertLessThan(swapTook, 4, "swapping service should take less than 4s, took \(swapTook.S)")
    }
    
    func test08_Swr3SwapSwappedService_IcyTriggerTooLate() throws {
        let swapTook = try playAndSwapSwappedService(ybridSwr3Endpoint, first: "swr-raka09", second: "swr-raka03")
        XCTAssertLessThan(swapTook, 4, "swapping service should take less than 4s, took \(swapTook.S)")
    }
    
    
    private func playAndSwapItem(_ endpoint:MediaEndpoint) throws -> TimeInterval {
        let semaphore = DispatchSemaphore(value: 0)
        let listener = TimingListener()

        var swapTriggered:Date?
        var swapTriggeredBuffer:TimeInterval?
        var swapComplete:Date?
        
        try AudioPlayer.open(for: endpoint, listener: nil,
             playbackControl: { (ctrl) in semaphore.signal()
                XCTFail(); return },
             ybridControl: { (ybridControl) in

                ybridControl.play()
                player_sdk_swiftTests.wait(ybridControl, until:PlaybackState.playing, maxSeconds:10)
              
                let ybrid = ybridControl as! YbridAudioPlayer
                swapTriggeredBuffer = ybrid.pipeline?.bufferSize
                swapTriggered = Date()
                ybridControl.swapItem() { (changed) in
                    swapComplete = Date()
                    print( "***** \(changed ? "":"not ")swapping item now *****")
                    sleep(2)
                    
                    ybridControl.close()
                    semaphore.signal()
                }
            }
        )
        _ = semaphore.wait(timeout: .distantFuture)
        let errCount = listener.errors.count
        guard errCount == 0 else {
            XCTFail("no error should occur")
            throw SessionError(ErrorKind.unknown, listener.errors[0].localizedDescription)
        }
        
        guard let swapStarted = swapTriggered, let bufferBefore = swapTriggeredBuffer,
              let swapTookS = swapComplete?.timeIntervalSince(swapStarted) else {
            XCTFail("unexpected")
            throw SessionError(ErrorKind.unknown, "swap or buffer duration missing")
        }
        let diff = swapTookS - bufferBefore
        Logger.shared.notice("buffer before \(bufferBefore.S) trigger, swapTook \(swapTookS.S) -> diff \(diff.S)")
        return swapTookS
    }
    
    private func playAndSwapService(_ endpoint:MediaEndpoint, to serviceId:String) throws -> TimeInterval {
        let semaphore = DispatchSemaphore(value: 0)
        let listener = TimingListener()

        var swapTriggered:Date?
        var swapTriggeredBuffer:TimeInterval?
        var swapComplete:Date?
        
        try AudioPlayer.open(for: endpoint, listener: nil,
             playbackControl: { (ctrl) in semaphore.signal()
                XCTFail(); return },
             ybridControl: { (ybridControl) in

                ybridControl.play()
                player_sdk_swiftTests.wait(ybridControl, until:PlaybackState.playing, maxSeconds:10)
              
                let ybrid = ybridControl as! YbridAudioPlayer
                swapTriggeredBuffer = ybrid.pipeline?.bufferSize
                
                swapTriggered = Date()
                ybridControl.swapService(to: serviceId) { (changed) in
                    XCTAssertTrue(changed, "should have changed service.")
                    swapComplete = Date()
                    print( "***** \(changed ? "":"not ")swapping service now *****")
                    sleep(2)
                    ybridControl.close()
                    semaphore.signal()
                }
            }
        )
        _ = semaphore.wait(timeout: .distantFuture)
        let errCount = listener.errors.count
        guard errCount == 0 else {
            XCTFail("no error should occur")
            throw SessionError(ErrorKind.unknown, listener.errors[0].localizedDescription)
        }
        
        guard let swapStarted = swapTriggered, let bufferBefore = swapTriggeredBuffer,
              let swapTookS = swapComplete?.timeIntervalSince(swapStarted) else {
            XCTFail("unexpected")
            throw SessionError(ErrorKind.unknown, "swap or buffer duration missing")
        }
        let diff = swapTookS - bufferBefore
        Logger.shared.notice("buffer before \(bufferBefore.S) trigger, swapping took \(swapTookS.S) -> diff \(diff.S)")
        return swapTookS
    }
    

    private func playAndSwapSwappedService(_ endpoint:MediaEndpoint, first serviceId1:String, second serviceId2:String) throws -> TimeInterval {
        let semaphore = DispatchSemaphore(value: 0)
        let listener = TimingListener()

        var swapTriggered:Date?
        var swapTriggeredBuffer:TimeInterval?
        var swapComplete:Date?
        
        try AudioPlayer.open(for: endpoint, listener: nil,
             playbackControl: { (ctrl) in semaphore.signal()
                XCTFail(); return },
             ybridControl: { (ybridControl) in

                ybridControl.play()
                player_sdk_swiftTests.wait(ybridControl, until:PlaybackState.playing, maxSeconds:10)
              
                let ybrid = ybridControl as! YbridAudioPlayer
                
                ybridControl.swapService(to: serviceId1) { (changed) in
                    XCTAssertTrue(changed, "should have changed service.")
                    print( "***** \(changed ? "":"not ")swapping service now *****")
                    sleep(2)
                    
                    
                    swapTriggered = Date()
                    swapTriggeredBuffer = ybrid.pipeline?.bufferSize
                    ybridControl.swapService(to: serviceId2) { (changed) in
                        XCTAssertTrue(changed, "should have changed service.")
                        swapComplete = Date()
                        print( "***** \(changed ? "":"not ")swapping service now *****")
                        sleep(2)
                        ybridControl.close()
                        semaphore.signal()
                    }
                    
                }
            }
        )
        _ = semaphore.wait(timeout: .distantFuture)
        let errCount = listener.errors.count
        guard errCount == 0 else {
            let err =  listener.errors[0]
            let errMessage = err.localizedDescription
            XCTFail(errMessage)
            throw SessionError(ErrorKind.unknown, errMessage)
        }
        
        guard let swapStarted = swapTriggered, let bufferBefore = swapTriggeredBuffer,
              let swapTookS = swapComplete?.timeIntervalSince(swapStarted) else {
            XCTFail("unexpected")
            throw SessionError(ErrorKind.unknown, "swap or buffer duration missing")
        }
        let diff = swapTookS - bufferBefore
        Logger.shared.notice("buffer before \(bufferBefore.S) trigger, swapping took \(swapTookS.S) -> diff \(diff.S)")
        return swapTookS
    }

 
    class TimingListener : AudioPlayerListener {
        var buffers:[TimeInterval] = []
        func stateChanged(_ state: PlaybackState) {}
        func metadataChanged(_ metadata: Metadata) {}
        func playingSince(_ seconds: TimeInterval?) {}
        func durationReadyToPlay(_ seconds: TimeInterval?) {}
        func durationConnected(_ seconds: TimeInterval?) {}
        func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {
            if let current = currentSeconds {
                buffers.append(current)
            }
        }
        
        var errors:[AudioPlayerError] = []
        func error(_ severity: ErrorSeverity, _ exception: AudioPlayerError) {
            errors.append(exception)
        }
    }
    
}


private func wait(_ control:YbridControl, until:PlaybackState, maxSeconds:Int) {
    let took = wait(max: maxSeconds) {
        return control.state == until
    }
    XCTAssertLessThanOrEqual(took, maxSeconds, "not \(until) within \(maxSeconds) s")
}

private func wait(max maxSeconds:Int, until:() -> (Bool)) -> Int {
    var seconds = 0
    while !until() && seconds <= maxSeconds {
        sleep(1)
        seconds += 1
    }
    XCTAssertTrue(until(), "condition not satisfied within \(maxSeconds) s")
    return seconds
}
