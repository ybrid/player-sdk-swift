//
// YbridSwapsTimingTests.swift
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

class YbridSwapsTimingTests: XCTestCase {
    
    var listener = TimingListener()
    override func setUpWithError() throws {
    }
    override func tearDownWithError() throws {
        listener.cleanUp()
    }

    func test01_ReconnectSession_Demo_ok() throws {
        let semaphore = DispatchSemaphore(value: 0)

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
                            Logger.testing.error(error.localizedDescription)
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
   
    func test02_SwapItemComplete_Demo() throws {
        
        let swapTook = try playAndSwapItem(ybridDemoEndpoint)
        XCTAssertLessThan(swapTook, 4, "swapping item should take less than 4s, took \(swapTook.S)")
        guard listener.errors.count == 0 else {
            XCTFail("swapping item should work")
            return
        }
      }
   
    func test03_SwapItemComplete_AdDemo() throws {
        let swapTook = try playAndSwapItem(ybridAdDemoEndpoint)
        XCTAssertLessThan(swapTook, 1, "not swapping item should take less than 1s, took \(swapTook.S)")
        guard listener.errors.count == 0 else {
            XCTFail("not swapping item should work")
            return
        }
      }
    
    func test04_SwapServiceComplete_Demo() throws {
        let swapTook = try playAndSwapService(ybridDemoEndpoint, to: "ad-injection-demo")
        XCTAssertLessThan(swapTook, 4, "swapping service should take less than 4s, took \(swapTook.S)")
        guard listener.errors.count == 0 else {
            XCTFail("swapping service should work")
            return
        }
    }
    
    func test05_SwapServiceComplete_Swr3() throws {
        let swapTook = try playAndSwapService(ybridSwr3Endpoint, to: "swr-raka06")
        XCTAssertLessThan(swapTook, 4, "swapping service should take less than 4s, took \(swapTook.S)")
        guard listener.errors.count == 0 else {
            XCTFail("swapping service should work")
            return
        }
    }
    
    
    func test06_SwapToSelfComplete_Demo_IcyTriggerInTime() throws {
        let swapTook = try playAndSwapService(ybridDemoEndpoint, to: "adaptive-demo")
        XCTAssertLessThan(swapTook, 1, "not swapping service should take less than 1s, took \(swapTook.S)")
        guard listener.errors.count == 0 else {
            XCTFail("not swapping service should work")
            return
        }
    }
    
    func test07_SwapSwappedServiceComplete_Demo_IcyTriggerInTime() throws {
        let swapTook = try playAndSwapSwappedService(ybridDemoEndpoint, first: "ad-injection-demo", second: "adaptive-demo")
        XCTAssertLessThan(swapTook, 4, "swapping service should take less than 4s, took \(swapTook.S)")
    }

    // there are ads where swap service is delayed until finished, for example
    // "Moin, Gerd hier. Ich steh' grad hier mit meinem 40er-Tonner auf'm Rastplatz..."
    func test08_SwapSwappedServiceComplete_AdDemo_IcyTriggerInTime() throws {
        let swapTook = try playAndSwapSwappedService(ybridAdDemoEndpoint, first: "adaptive-demo", second: "ad-injection-demo")
        XCTAssertLessThan(swapTook, 4, "swapping service should take less than 4s, took \(swapTook.S)")
    }
    
    func test09_SwapBackSwappedService_Swr3_IcyTriggerTooLate() throws {
        let swapTook = try playAndSwapSwappedService(ybridSwr3Endpoint, first: "swr-raka09", second: "swr3-live")
        XCTAssertLessThan(swapTook, 4, "swapping service should take less than 4s, took \(swapTook.S)")
    }
  
    func test10_SwapSwappedService_Swr3_IcyTriggerTooLate() throws {
        let swapTook = try playAndSwapSwappedService(ybridSwr3Endpoint, first: "swr-raka09", second: "swr-raka05")
        XCTAssertLessThan(swapTook, 4, "swapping service should take less than 4s, took \(swapTook.S)")
    }
    
 
    private func playAndSwapItem(_ endpoint:MediaEndpoint) throws -> TimeInterval {
        let semaphore = DispatchSemaphore(value: 0)
        let listener = TimingListener()

        var swapTriggered:Date?
        var swapComplete:Date?
        var swapped = false
        
        try AudioPlayer.open(for: endpoint, listener: listener,
             playbackControl: { (ctrl) in semaphore.signal()
                XCTFail(); return },
             ybridControl: { (ybridControl) in

                ybridControl.play()
                player_sdk_swiftTests.wait(ybridControl, until:PlaybackState.playing, maxSeconds:10)
                sleep(2)
                
                swapTriggered = Date()
                ybridControl.swapItem() { (changed) in
                    swapped = changed
                    swapComplete = Date()
                    Logger.testing.info( "***** now ***** \(changed ? "":"not ")swapping item")
                    sleep(6)
                    ybridControl.stop()
                    sleep(1)
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
        
        guard let swapStarted = swapTriggered,
              let swapTookS = swapComplete?.timeIntervalSince(swapStarted) else {
            XCTFail("unexpected")
            throw SessionError(ErrorKind.unknown, "swap started or completed missing")
        }
        Logger.testing.debug("\(swapped ? "":"not ")swapping item took \(swapTookS.S)")
        return swapTookS
    }
    
    private func playAndSwapService(_ endpoint:MediaEndpoint, to serviceId:String) throws -> TimeInterval {
        let semaphore = DispatchSemaphore(value: 0)
        let listener = TimingListener()

        var swapTriggered:Date?
        var swapComplete:Date?
        var swapped = false
        
        try AudioPlayer.open(for: endpoint, listener: listener,
             playbackControl: { (ctrl) in semaphore.signal()
                XCTFail(); return },
             ybridControl: { (ybridControl) in

                ybridControl.play()
                player_sdk_swiftTests.wait(ybridControl, until:PlaybackState.playing, maxSeconds:10)
                sleep(2)
                
                swapTriggered = Date()
                ybridControl.swapService(to: serviceId) { (changed) in
                    swapped = changed
                    swapComplete = Date()
                    Logger.testing.notice("***** now ***** \(changed ? "":"not ")swapping service")
                    sleep(6)
                    ybridControl.stop()
                    sleep(1)
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
        
        guard let swapStarted = swapTriggered,
              let swapTookS = swapComplete?.timeIntervalSince(swapStarted) else {
            XCTFail("unexpected")
            throw SessionError(ErrorKind.unknown, "swap staerted or completed missing")
        }
        Logger.testing.debug("\(swapped ? "":"not ")swapping took \(swapTookS.S)")
        return swapTookS
    }
    

    private func playAndSwapSwappedService(_ endpoint:MediaEndpoint, first serviceId1:String, second serviceId2:String) throws -> TimeInterval {
        let semaphore = DispatchSemaphore(value: 0)
        let listener = TimingListener()

        var swapTriggered:Date?
        var swapComplete:Date?
        
        try AudioPlayer.open(for: endpoint, listener: listener,
             playbackControl: { (ctrl) in semaphore.signal()
                XCTFail(); return },
             ybridControl: { (ybridControl) in

                ybridControl.play()
                player_sdk_swiftTests.wait(ybridControl, until:PlaybackState.playing, maxSeconds:10)
                sleep(2)
                
                ybridControl.swapService(to: serviceId1) { (changed) in
                    XCTAssertTrue(changed, "should have changed service.")
                    Logger.testing.notice( "***** now ***** \(changed ? "":"not ")swapping service")
                    sleep(2)
                    
                    
                    swapTriggered = Date()
                    ybridControl.swapService(to: serviceId2) { (changed) in
                        XCTAssertTrue(changed, "should have changed service.")
                        swapComplete = Date()
                        Logger.testing.notice( "***** now ***** \(changed ? "":"not ")swapping service")
                        sleep(2)
                        ybridControl.stop()
                        sleep(1)
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
        
        guard let swapStarted = swapTriggered,
              let swapTookS = swapComplete?.timeIntervalSince(swapStarted) else {
            XCTFail("unexpected")
            throw SessionError(ErrorKind.unknown, "swap or buffer duration missing")
        }
        Logger.testing.debug("swapping took \(swapTookS.S)")
        return swapTookS
    }

}

