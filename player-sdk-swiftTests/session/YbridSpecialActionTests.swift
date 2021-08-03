//
// YbridSpecialActionTests.swift
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

class YbridSpecialActionTests: XCTestCase {
    
    var listener = ErrorListener()
    override func setUpWithError() throws {
    }
    override func tearDownWithError() throws {
        listener.cleanUp()
    }

    func test01_ReconnectSession_ok() throws {
        let semaphore = DispatchSemaphore(value: 0)

        try AudioPlayer.open(for: ybridDemoEndpoint, listener: listener,
             playbackControl: { (c) in
                return },
             ybridControl: { (ybridControl) in
                if let ybrid = ybridControl as? YbridAudioPlayer {
                    if let driver = ybrid.session.driver as? YbridV2Driver {
                        print("base uri is \(driver.state.baseUrl)")
                        let baseUrlOrig = driver.state.baseUrl
                        
                        // forcing to reconnect
                        do {
                            try driver.reconnect()
                        } catch {
                            Logger.session.error(error.localizedDescription)
                            XCTFail("should work, but \(error.localizedDescription)")
                        }
                        print("base uri is \(driver.state.baseUrl)")
                        let baseUrlReconnected = driver.state.baseUrl
                        XCTAssertEqual(baseUrlOrig, baseUrlReconnected)
 
                    
                        ybrid.play()
                        print("base uri is \(driver.state.baseUrl)")
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
    
    func test02_ChangeBitrates_All__lt32gt160fail() throws {
        let bitrates = [8, 16, 32, 40, 48, 56, 64, 80, 96, 112,
                        128, 160, 192, 224, 256, 320, 352, 384, 416, 448]
        
        let semaphore = DispatchSemaphore(value: 0)
        var adoptedRates:[Int32] = []
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: listener,
             playbackControl: { (c) in
                return },
             ybridControl: { (ybridControl) in
                guard let ybrid = ybridControl as? YbridAudioPlayer else {
                    XCTFail(); semaphore.signal(); return
                }
                ybrid.play()
                sleep(4)
                
                bitrates.forEach{
                    let kbps = Int32($0)*1000
                    ybrid.session.maxBitRate(to:kbps)
                    sleep(1)
                    XCTAssertEqual(kbps, ybrid.bitRate)
                    if kbps == ybrid.bitRate {
                        adoptedRates.append(kbps)
                    }
                }
                
                ybridControl.close()
                sleep(1)
                semaphore.signal()
             })
        _ = semaphore.wait(timeout: .distantFuture)
        let errCount = listener.errors.count
        guard errCount == 0 else {
            XCTFail("recreating session should work")
            return
        }
        print("adopted bit rates are \(adoptedRates)")
    }

    func test03_ChangeBitrateVague_ok() throws {
        let semaphore = DispatchSemaphore(value: 0)
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: listener,
             playbackControl: { (c) in
                return },
             ybridControl: { (ybridControl) in
                guard let ybrid = ybridControl as? YbridAudioPlayer else {
                    XCTFail(); semaphore.signal(); return
                }
                ybrid.play()
                sleep(4)
                
                ybrid.session.maxBitRate(to:77)
                sleep(1)
                XCTAssertEqual(32_000, ybrid.bitRate)
                
                ybrid.session.maxBitRate(to:31_000)
                sleep(1)
                XCTAssertEqual(32_000, ybrid.bitRate)
                
                ybrid.session.maxBitRate(to:57_000)
                sleep(1)
                XCTAssertEqual(56_000, ybrid.bitRate)
                
                ybrid.session.maxBitRate(to:191_999)
                sleep(1)
                XCTAssertEqual(160_000, ybrid.bitRate)
                
                ybrid.session.maxBitRate(to:390291781)
                sleep(1)
                XCTAssertEqual(-1, ybrid.bitRate)
                
                ybridControl.close()
                sleep(1)
                semaphore.signal()
             })
        _ = semaphore.wait(timeout: .distantFuture)
        let errCount = listener.errors.count
        guard errCount == 0 else {
            XCTFail("recreating session should work")
            return
        }
    }
    

    
    
}

