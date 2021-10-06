//
// YbridBitrateTests.swift
// player-sdk-swift
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

class YbridBitrateTests: XCTestCase {

    let maxCtrlComplete = 0.5
    
    let listener = TestYbridPlayerListener()
    override func setUpWithError() throws {
        listener.logPlayingSince = false
        listener.logBufferSize = false
        listener.logMetadata = false
        listener.reset()
    }
    override func tearDownWithError() throws {
        let bitrates = listener.bitrates
        let maxRates = bitrates.map{ $0.max }
        let currentRates = bitrates.map{ $0.current }
        Logger.testing.info("-- consumed max bit rates \(maxRates)")
        Logger.testing.info("-- consumed current bit rates \(currentRates)")
    }

    // supported bitrates for mp3
    let possibleBitratesKbps = [8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112,
                    128, 160, 192, 224, 256, 320, 352, 384, 416, 448]
    
    // used in standard nacamar's streams (see public var bitratesRange)
    let supportedBitratesKbps = [32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192]
    
    
    func test01_stopped_maxBitRate_acknowledged() throws {
        
        let test = TestYbridControl(ybridDemoEndpoint, listener: listener)
        test.stopped() {  [self] (ybrid:YbridControl) in
            
            XCTAssertNil(listener.maxBitRate)
            
            ybrid.maxBitRate(to: 32_000)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            
            XCTAssertEqual(listener.maxBitRate, 32_000)
            
            ybrid.play()
            sleep(4)
            XCTAssertEqual(listener.maxBitRate, 32_000)
            XCTAssertGreaterThanOrEqual(listener.currentBitRate ?? 0, 32_000)
        }
    }
    
    func test02_maxBitRate_notify_onlyWhenPlayingAndSet() throws {
        
        let test = TestYbridControl(ybridDemoEndpoint, listener: listener)
        test.stopped() { [self] (ybrid:YbridControl) in
            
            
            XCTAssertNil(listener.maxBitRate)
            XCTAssertNil(listener.currentBitRate)
            XCTAssertEqual(0, listener.maxRateNotifications)
            
            
            // Setting max bit-rate when still stoppt is acknoleged.
            ybrid.maxBitRate(to: 12_345)
            Thread.sleep(forTimeInterval: maxCtrlComplete)

            // It does not adjust max bit-rate to one of the provided bitrates.
            XCTAssertEqual(listener.maxBitRate, 12_345)
            
            
            // Setting max bit-rate when still stoppt is acknoleged.
            ybrid.maxBitRate(to: 54_321)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            
            let notifiedCountStopped = listener.maxRateNotifications
            XCTAssertGreaterThanOrEqual(notifiedCountStopped, 2) // greater only on item changes

            // It does not adjust max bit-rate to one of the provided bitrates.
            XCTAssertEqual(listener.maxBitRate, 54_321)
            
            
            // When playing max bitrate value is notified, but remains unchanged.
            ybrid.play()
            _ = test.poller.wait(max: 3) { return ybrid.state == PlaybackState.playing }
            
            sleep(1) // could be 60
            let notifiedCountPlaying1 = listener.maxRateNotifications
            XCTAssertGreaterThan(notifiedCountPlaying1, notifiedCountStopped)
            XCTAssertLessThanOrEqual(notifiedCountPlaying1 - notifiedCountStopped, 2) // by 1, except on item change
            XCTAssertEqual(listener.maxBitRate, 54_321)
            
            
            // The Response value is changing only when setting during play.
            ybrid.maxBitRate(to: 12_345)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            let notifiedCountPlaying2 = listener.maxRateNotifications
            XCTAssertGreaterThan(notifiedCountPlaying2, notifiedCountPlaying1)
            XCTAssertLessThanOrEqual(notifiedCountPlaying2 - notifiedCountPlaying1, 2) // by 1, except on item change
        }
    }
    
    
    
    func test03_playing_maxBitRate_mininum() throws {
        
        let test = TestYbridControl(ybridDemoEndpoint, listener: listener)
        test.playing() { [self] (ybrid) in
            
            sleep(1)
            
            XCTAssertNil(listener.maxBitRate)
            XCTAssertEqual(0, listener.maxRateNotifications)
            
            XCTAssertGreaterThanOrEqual(listener.currentBitRate ?? 0, bitRatesRange.lowerBound)
            
            ybrid.maxBitRate(to:77)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(1, listener.maxRateNotifications) // except on item changes
            XCTAssertEqual(listener.maxBitRate!, 8_000)
        }
    }

    func test04_playing_maxBitRate_maxinum_fails() throws {
        
        let test = TestYbridControl(ybridDemoEndpoint, listener: listener)
        test.playing() { [self] (ybrid) in
            
            XCTAssertNil(listener.maxBitRate)
            XCTAssertEqual(0, listener.maxRateNotifications)
            
            XCTAssertLessThanOrEqual(listener.currentBitRate ?? 0, bitRatesRange.upperBound)
            
            ybrid.maxBitRate(to:1_000_000)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(1, listener.maxRateNotifications) //  fails -1 from server leads to "no change" in SDK
            XCTAssertNotNil(listener.maxBitRate) // fails, nothing (-1) is responded
            XCTAssertEqual(listener.maxBitRate, bitRatesRange.upperBound) //
        }
    }

    func test05_playing_maxBitRate_useLower_fails() throws {
        
        let test = TestYbridControl(ybridDemoEndpoint, listener: listener)
        test.playing() { [self] (ybrid) in
            
            XCTAssertNil(listener.maxBitRate)
            XCTAssertEqual(0, listener.maxRateNotifications)
            

            ybrid.maxBitRate(to:42_000)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate!, 40_000) // should be but fails
            XCTAssertNotEqual(listener.maxBitRate!, 48_000) // fails, the higher one is responeded
            
            
            ybrid.maxBitRate(to:143_000)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate!, 128_000) // fails, but should be
            XCTAssertNotEqual(listener.maxBitRate!, 160_000) // fails, the higher one is responeded
        }
    }
    
    
    func test06_playing_maxBitRate_8k() throws {
        
        let test = TestYbridControl(ybridDemoEndpoint, listener: listener)
        test.playing() { [self] (ybrid) in
             
            XCTAssertNil(listener.maxBitRate)
            
            ybrid.maxBitRate(to:8_000)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate, 8_000)
        }
    }

    func test07_playing_maxBitRate_64k() throws {
        
        let test = TestYbridControl(ybridDemoEndpoint, listener: listener)
        test.playing() { [self] (ybrid) in
             
            XCTAssertNil(listener.maxBitRate)
            
            ybrid.maxBitRate(to:64_000)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate, 64_000)
        }
    }
    
    func test08_playing_maxBitRate_192k() throws {
        
        let test = TestYbridControl(ybridDemoEndpoint, listener: listener)
        test.playing() { [self] (ybrid) in
             
            XCTAssertNil(listener.maxBitRate)
            XCTAssertGreaterThanOrEqual(listener.currentBitRate ?? 0, 8_000)
            
            ybrid.maxBitRate(to:192_000)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate, 192_000)
 
        }
    }
    
    
    func test10_stopped_currentBitRate() throws {
        
        let test = TestYbridControl(ybridDemoEndpoint, listener: listener)
        test.stopped() {  [self] (ybrid:YbridControl) in
            XCTAssertNil(listener.currentBitRate)
        }
    }
    
    func test11_playing_currentBitRate() throws {
        
        let test = TestYbridControl(ybridDemoEndpoint, listener: listener)
        test.playing() {  [self] (ybrid:YbridControl) in
            XCTAssertGreaterThanOrEqual(listener.currentBitRate ?? 0, 32_000)
        }
    }

    
    func test12_stopped_maxChange_playing_currentBitRate() throws {
        
        let test = TestYbridControl(ybridDemoEndpoint, listener: listener)
        test.stopped() {  [self] (ybrid:YbridControl) in
            
            XCTAssertNil(listener.currentBitRate)

            XCTAssertEqual(0, listener.maxRateNotifications)
            ybrid.maxBitRate(to: 32_000)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate, 32_000)
            
            XCTAssertNil(listener.currentBitRate)
            
            
            ybrid.play()
            _ = test.poller.wait(max: 3) { return ybrid.state == .playing }
            XCTAssertEqual(listener.currentBitRate, 32_000)
        }
    }
    
    
}
