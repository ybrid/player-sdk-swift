//
// YbridControlOtherTests.swift
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

class YbridControlBasicTests: XCTestCase {

    let listener = TestYbridPlayerListener()
    var testYbridControl:TestYbridControl?
    override func setUpWithError() throws {
        listener.reset()
        testYbridControl = TestYbridControl(ybridDemoEndpoint, listener: listener)
    }
    override func tearDownWithError() throws {
        Logger.testing.debug("-- consumed offsets \(listener.offsets)")
        let servicesIds = listener.services.map{$0.map{(service) in return service.identifier}}
        Logger.testing.debug("-- consumed services \(servicesIds)")
        Logger.testing.debug("-- consumed swaps \(listener.swaps)")
        Logger.testing.debug("-- consumed metadata \(listener.metadatas.count)")
    }
    
    
    /*
     The listener is notified of ybrid states in the beginning of the session.
     */
    func test01_Stopped() {
        
        guard let ybridControl = testYbridControl else {
            XCTFail("cannot use ybrid control.")
            return
        }
        
        ybridControl.stopped() { (ybridControl) in
            usleep(10_000) /// because the listener notifies asyncronously it *may* take some millis
        }
        
        XCTAssertEqual(listener.services.count, 1, "YbridControlListener.serviceChanged(...) should have been called once, but was \(listener.services.count)")
        
        XCTAssertGreaterThanOrEqual(listener.offsets.count, 1, "YbridControlListener.offsetToLiveChanged(...) should have been called at least once, but was \(listener.offsets.count), \(listener.offsets)")
        
        XCTAssertEqual(listener.swaps.count, 1, "YbridControlListener.swapsChanged(...) should have been called once, but was \(listener.swaps.count)")

        XCTAssertEqual(listener.metadatas.count, 0, "YbridControlListener.metadataChanged(...) should not be called, but was \(listener.metadatas.count)")
    }
    
    /*
     The listener's methods are called when the specific state changes or
     when refresh() is called.
     */
    func test02_Stopped_Refresh() {
        
        guard let ybridControl = testYbridControl else {
            XCTFail("cannot use ybrid control.")
            return
        }
        
        ybridControl.stopped() { (ybridControl) in
            
            ybridControl.refresh()
            usleep(20_000) /// because the listener is notified asyncronously it *may* take some millis on old devices
        }
        
        XCTAssertEqual(listener.services.count, 2, "YbridControlListener.serviceChanged(...) should have been called twice, but was \(listener.services.count)")
        
        XCTAssertTrue((1...3).contains(listener.offsets.count), "YbridControlListener.offsetToLiveChanged(...) should have been called \(2...3), but was \(listener.offsets.count), \(listener.offsets)")
        
        XCTAssertEqual(listener.swaps.count, 2,"YbridControlListener.swapsChanged(...) should have been called twice, but was \(listener.swaps.count)")

        XCTAssertEqual(listener.metadatas.count, 1, "YbridControlListener.metadataChanged(...) should not be called once, but was \(listener.metadatas.count)")
    }

    
    /*
     The listener is notified of ybrid states in the beginning of the session.
     The listeners methods are called when the specific state changes or
     when refresh() is called.
     */
    func test03_Playing_Refresh() throws {
        
        guard let ybridControl = testYbridControl else {
            XCTFail("cannot use ybrid control.")
            return
        }
        
        ybridControl.playing() { (ybridControl) in
            
            ybridControl.refresh()
            usleep(10_000) /// because the listener notifies asyncronously it *may* take some millis
        }
        
        XCTAssertEqual(2, listener.services.count, "YbridControlListener.serviceChanged(...) should have been called twice, but was \(listener.services.count)")
        
        let expectedOffsets = 2...4
        XCTAssertTrue(expectedOffsets.contains(listener.offsets.count), "YbridControlListener.offsetToLiveChanged(...) should have been called \(expectedOffsets), but was \(listener.offsets.count), \(listener.offsets)")
        
        let expectedSwapCalls = 2...3
        XCTAssertTrue(expectedSwapCalls.contains(listener.swaps.count), "YbridControlListener.swapsChanged(...) should have been called \(expectedSwapCalls) times, but was \(listener.swaps.count)")
        
        XCTAssertGreaterThanOrEqual( listener.metadatas.count, 2, "YbridControlListener.metadataChanged(...) should be called at least twice, but was \(listener.metadatas.count)")
    }

    
    /*

     */
    let bitrates = [32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320 ]
    func test04_ChangeBitrates_All() throws {
        
        guard let test = testYbridControl else {
            XCTFail("cannot use ybrid test control.")
            return
        }
        var adoptedRates:[Int32] = []
        test.playing() { (ybrid) in
            
            self.bitrates.forEach{
                let kbps = Int32($0)*1000
                ybrid.changeBitrate(to:kbps)
                
                usleep(800_000)
                XCTAssertEqual(kbps, ybrid.maxBitrate)
                if kbps == ybrid.maxBitrate {
                    adoptedRates.append(kbps)
                }
            }
        }
        Logger.testing.info("adopted bit rates are \(adoptedRates)")
    }

    
    func test04_ChangeBitrates_nextRates() throws {
        
        guard let test = testYbridControl else {
            XCTFail("cannot use ybrid test control.")
            return
        }
        test.playing() { (ybrid) in
            
            ybrid.changeBitrate(to:31_000)
            usleep(800_000)
            XCTAssertEqual(32_000, ybrid.maxBitrate)
            
            ybrid.changeBitrate(to:57_000)
            usleep(800_000)
            XCTAssertEqual(56_000, ybrid.maxBitrate)
        }
    }
}

