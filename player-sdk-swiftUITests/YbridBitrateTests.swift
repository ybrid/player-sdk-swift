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


/* *******************************************************************
 * declare endpoint under test and bitrates configured on ybrid server
 *
 * testEndpoint
 * endpointAvailableRates
 * *******************************************************************/

let testEndpoint = ybridDemoEndpoint
let endpointAvailableRates:[Int32] = supportedBitratesKbps.map{ Int32($0 * 1000) }

//let testEndpoint = ybridAdDemoEndpoint
//let endpointAvailableRates:[Int32] = [128_000]

//let testEndpoint = ybridStageSwr3Endpoint
//let endpointAvailableRates:[Int32] = [64_000, 80_000, 128_000, 192_000]


// constants

// possibly supported bitrates for mp3s
let possibleBitratesKbps = [8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112,
                128, 160, 192, 224, 256, 320, 352, 384, 416, 448]
// used in standard nacamar's streams (see public var bitratesRange)
let supportedBitratesKbps = [32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192]


// max duration to wait for response
let maxCtrlComplete = 1.0
// max duration to wait for playing audio to be affected
let maxAudioComplete:TimeInterval = 5.0


class YbridBitrateLimitTests: XCTestCase {
    
    let listener = TestYbridPlayerListener()
    
    override func setUpWithError() throws {
        listener.logPlayingSince = false
        listener.logBufferSize = false
        listener.logMetadata = false
        listener.logOffset = false
        listener.logSwapsLeft = false
        listener.reset()
    }
    override func tearDownWithError() throws {
        let bitrates = listener.bitrates
        let maxRates = bitrates.map{ $0.limit }
        let currentRates = bitrates.map{ $0.current }
        Logger.testing.info("-- consumed max bit rates \(maxRates)")
        Logger.testing.info("-- consumed current bit rates \(currentRates)")
    }
    
    func test01_stopped_setMax_acknowledged() throws {
        
        let test = TestYbridControl(testEndpoint, listener: listener)
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
    
    func test02_stopped_setMaxVague_acknowleged() throws {
        
        let test = TestYbridControl(testEndpoint, listener: listener)
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
    
    
    func test03_playing_maxBitRate_tooLow() throws {
        
        let test = TestYbridControl(testEndpoint, listener: listener)
        test.playing() { [self] (ybrid) in
            
            XCTAssertNil(listener.maxBitRate)
            XCTAssertEqual(0, listener.maxRateNotifications)
            
            XCTAssertGreaterThanOrEqual(listener.currentBitRate ?? 0, endpointAvailableRates.min() ?? bitRatesRange.lowerBound)
            
            ybrid.maxBitRate(to:77)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(1, listener.maxRateNotifications) // except on item changes
            XCTAssertEqual(listener.maxBitRate!, endpointAvailableRates.min() ?? bitRatesRange.lowerBound)
        }
    }

    func test04_playing_maxBitRate_tooHigh_fails() throws {
        
        let test = TestYbridControl(testEndpoint, listener: listener)
        test.playing() { [self] (ybrid) in
            
            XCTAssertNil(listener.maxBitRate)
            XCTAssertEqual(0, listener.maxRateNotifications)
            
            XCTAssertLessThanOrEqual(listener.currentBitRate ?? 0, bitRatesRange.upperBound)
            
            ybrid.maxBitRate(to:1_000_000)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(1, listener.maxRateNotifications) //  fails -1 from server leads to "no change" in SDK
            XCTAssertNotNil(listener.maxBitRate) // fails, nothing (-1) is responded
            XCTAssertEqual(listener.maxBitRate, endpointAvailableRates.max() ?? bitRatesRange.upperBound) //
        }
    }

    // ok @ stagecast, fails @ democast
    func test05_playing_maxBitRate_useLower_fails() throws {
        
        let test = TestYbridControl(testEndpoint, listener: listener)
        test.playing() { [self] (ybrid) in
            
            XCTAssertNil(listener.maxBitRate)
            XCTAssertEqual(0, listener.maxRateNotifications)
            

            ybrid.maxBitRate(to:70_000)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate!, 64_000)
            
            
            ybrid.maxBitRate(to:143_000)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate!, 128_000)
        }
    }
    
    
    func test06_playing_maxBitRate_Lowest() throws {
        
        let test = TestYbridControl(testEndpoint, listener: listener)
        test.playing() { [self] (ybrid) in
             
            XCTAssertNil(listener.maxBitRate)
            
            ybrid.maxBitRate(to:endpointAvailableRates.min() ?? bitRatesRange.lowerBound)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate, endpointAvailableRates.min() ?? bitRatesRange.lowerBound)
        }
    }

 
    func test07_playing_maxBitRate_64k() throws {
        
        let test = TestYbridControl(testEndpoint, listener: listener)
        test.playing() { [self] (ybrid) in
             
            XCTAssertNil(listener.maxBitRate)
            
            ybrid.maxBitRate(to:64_000)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate, 64_000)
        }
    }
    
    func test08_playing_maxBitRate_128k() throws {
        
        let test = TestYbridControl(testEndpoint, listener: listener)
        test.playing() { [self] (ybrid) in
             
            XCTAssertNil(listener.maxBitRate)
            
            ybrid.maxBitRate(to:128_000)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate, 128_000)
        }
    }
    
    
    func test09_playing_maxBitRate_Highest() throws {
        
        let test = TestYbridControl(testEndpoint, listener: listener)
        test.playing() { [self] (ybrid) in
             
            XCTAssertNil(listener.maxBitRate)
            XCTAssertGreaterThanOrEqual(listener.currentBitRate ?? 0, 8_000)
            
            ybrid.maxBitRate(to:endpointAvailableRates.max() ?? bitRatesRange.upperBound)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate, endpointAvailableRates.max() ?? bitRatesRange.upperBound)
 
        }
    }
    
}

class YbridBitrateCurrentTests: XCTestCase {
    
    let listener = TestYbridPlayerListener()
    
    override func setUpWithError() throws {
        listener.logPlayingSince = false
        listener.logBufferSize = false
        listener.logMetadata = false
        listener.logOffset = false
        listener.logSwapsLeft = false
        listener.reset()
    }
    override func tearDownWithError() throws {
        let bitrates = listener.bitrates
        let maxRates = bitrates.map{ $0.limit }
        let currentRates = bitrates.map{ $0.current }
        Logger.testing.info("-- consumed max bit rates \(maxRates)")
        Logger.testing.info("-- consumed current bit rates \(currentRates)")
    }

    func test10_stopped_currentBitRate_isNil() throws {
        
        let test = TestYbridControl(testEndpoint, listener: listener)
        test.stopped() {  [self] (ybrid:YbridControl) in
            XCTAssertNil(listener.currentBitRate)
        }
    }

    func test11_playing_currentBitRate_isMax() throws {
        
        let test = TestYbridControl(testEndpoint, listener: listener)
        test.playing() {  [self] (ybrid:YbridControl) in
            guard let currentRate = listener.currentBitRate else {
                XCTFail("expected a current bit-rate"); return
            }
            XCTAssertGreaterThanOrEqual(currentRate, endpointAvailableRates.min() ?? bitRatesRange.lowerBound )
            XCTAssertEqual(currentRate, endpointAvailableRates.max() )
        }
    }
    
    
    func test12_stopped_setBelowMin_play_current_isMin() throws {
        
        let test = TestYbridControl(testEndpoint, listener: listener)
        test.stopped() {  [self] (ybrid:YbridControl) in
            let bitrateSet:Int32 = 6_000
            let bitrateResult:Int32 = endpointAvailableRates.min() ?? bitRatesRange.lowerBound

            ybrid.maxBitRate(to:bitrateSet)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate, bitrateSet) // should be bitrateResult

            ybrid.play()
            Thread.sleep(forTimeInterval: maxAudioComplete)
            XCTAssertEqual(listener.currentBitRate ?? 0, bitrateResult)
        }
    }
    
    func test13_stopped_setMaxProvided_play_current_isProvided() throws {
        
        let test = TestYbridControl(testEndpoint, listener: listener)
        test.stopped() {  [self] (ybrid:YbridControl) in
            let bitrateSet:Int32 = 64_000
            let bitrateResult:Int32 = 64_000
            

            ybrid.maxBitRate(to:bitrateSet)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate, bitrateSet) // should be bitrateResult

            ybrid.play()
            Thread.sleep(forTimeInterval: maxAudioComplete)
            XCTAssertEqual(listener.currentBitRate ?? 0, bitrateResult)
        }
    }
    
    
    func test14_stopped_setMaxTooHigh_play_current_isMax() throws {
        
        let test = TestYbridControl(testEndpoint, listener: listener)
        test.stopped() {  [self] (ybrid:YbridControl) in
            let bitrateSet:Int32 = 1_000_000
            let bitrateResult:Int32 = endpointAvailableRates.max() ?? bitRatesRange.upperBound

            ybrid.maxBitRate(to:bitrateSet)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate, bitrateSet) // should be bitrateResult

            ybrid.play()
            Thread.sleep(forTimeInterval: maxAudioComplete)
            XCTAssertEqual(listener.currentBitRate ?? 0, bitrateResult)
        }
    }
    
    
    func test15_stopped_setVague_play_current_isLowerProvided() throws {
        
        let test = TestYbridControl(testEndpoint, listener: listener)
        test.stopped() {  [self] (ybrid:YbridControl) in
            let bitrateSet:Int32 = 64_010
            let bitrateResult:Int32 = 64_000
            

            ybrid.maxBitRate(to:bitrateSet)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate, bitrateSet) // should be bitrateResult

            ybrid.play()
            Thread.sleep(forTimeInterval: maxAudioComplete)
            XCTAssertEqual(listener.currentBitRate ?? 0, bitrateResult)
        }
    }
    
    
    func test16_playing_setTooHigh_current_isMax() throws {
        
        let test = TestYbridControl(testEndpoint, listener: listener)
        test.playing() {  [self] (ybrid:YbridControl) in

            let bitrateSet:Int32 = 1_000_000
            let bitrateResult =  endpointAvailableRates.max() ?? bitRatesRange.upperBound
            
            ybrid.maxBitRate(to:bitrateSet)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate, bitrateSet) // should be bitrateResult

            provokeCurrentBitrate(ybrid)
            XCTAssertEqual(listener.currentBitRate, bitrateResult)
        }
    }
    
    func test17_playing_current_vagueTooHighTooLow() throws {
        
        let test = TestYbridControl(testEndpoint, listener: listener)
        test.playing() {  [self] (ybrid:YbridControl) in
            var bitrateSet:Int32 = 64_001
            var bitrateResult:Int32 = 64_000
            

            ybrid.maxBitRate(to:bitrateSet)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate, bitrateSet) // should be bitrateResult
            
            provokeCurrentBitrate(ybrid)
            XCTAssertEqual(listener.currentBitRate, bitrateResult)

            
            bitrateSet = 1_000_000
            bitrateResult = 192_000
            
            ybrid.maxBitRate(to:bitrateSet)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate, bitrateSet) // should be bitrateResult

            provokeCurrentBitrate(ybrid)
            XCTAssertEqual(listener.currentBitRate, bitrateResult)
            
            
            bitrateSet = 1_000
            bitrateResult = endpointAvailableRates.min() ?? 8_000
            
            ybrid.maxBitRate(to:bitrateSet)
            Thread.sleep(forTimeInterval: maxCtrlComplete)
            XCTAssertEqual(listener.maxBitRate, bitrateSet) // should be bitrateResult

            provokeCurrentBitrate(ybrid)
            XCTAssertEqual(listener.currentBitRate, bitrateResult)
        }
    }
    
    private func provokeCurrentBitrate(_ ybrid:YbridControl) {
        ybrid.stop()
        sleep(1)
        ybrid.play()
        Poller().wait(ybrid, until: .playing, maxSeconds: 4)
//        Thread.sleep(forTimeInterval: maxCtrlComplete)
    }

    
 
}
