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
    override func setUpWithError() throws {
        listener.reset()
    }
    override func tearDownWithError() throws {
        Logger.testing.info("-- consumed offsets \(listener.offsets)")
        let servicesIds = listener.services.map{$0.map{(service) in return service.identifier}}
        Logger.testing.info("-- consumed services \(servicesIds)")
        Logger.testing.info("-- consumed swaps \(listener.swaps)")
        Logger.testing.info("-- consumed max bit rates \(listener.bitrates)")
        Logger.testing.info("-- consumed metadata \(listener.metadatas.count)")
    }
    
    
    /*
     The listener is notified of ybrid states in the beginning of the session.
     */
    func test01_stopped() {
        
        let test = TestYbridControl(ybridDemoEndpoint, listener: listener)
        test.stopped() { (ybrid) in
            usleep(10_000) /// because the listener notifies asyncronously it *may* take some millis
        }
        
        XCTAssertEqual(listener.services.count, 0, "YbridControlListener.serviceChanged(...) should not be called with adaptive demo, but was \(listener.services.count)")
        
        XCTAssertGreaterThanOrEqual(listener.offsets.count, 1, "YbridControlListener.offsetToLiveChanged(...) should have been called at least once, but was \(listener.offsets.count), \(listener.offsets)")
        
        XCTAssertEqual(listener.swaps.count, 1, "YbridControlListener.swapsChanged(...) should have been called once, but was \(listener.swaps.count)")

        XCTAssertEqual(listener.metadatas.count, 0, "YbridControlListener.metadataChanged(...) should not be called, but was \(listener.metadatas.count)")
    }
    
    /*
     The listener's methods are called when the specific state changes or
     when refresh() is called.
     */
    func test02_stopped_Select() {
        
        let test = TestYbridControl(ybridDemoEndpoint, listener: listener)
        test.stopped() { (ybrid:YbridControl) in
            ybrid.select()
            usleep(20_000) /// because the listener is notified asyncronously it *may* take some millis on old devices
        }
        
        XCTAssertEqual(listener.services.count, 1, "YbridControlListener.serviceChanged(...) should have been called on refresh, but was \(listener.services.count)")
        
        if let services = listener.services.first  {
            XCTAssertEqual(services.count, 0)
        } else {
            XCTFail()
        }
        
        XCTAssertTrue((1...3).contains(listener.offsets.count), "YbridControlListener.offsetToLiveChanged(...) should have been called \(2...3), but was \(listener.offsets.count), \(listener.offsets)")
        
        XCTAssertEqual(listener.swaps.count, 2,"YbridControlListener.swapsChanged(...) should have been called twice, but was \(listener.swaps.count)")

        XCTAssertEqual(listener.metadatas.count, 1, "YbridControlListener.metadataChanged(...) should not be called once, but was \(listener.metadatas.count)")
    }

    
    /*
     The listener is notified of ybrid states in the beginning of the session.
     The listeners methods are called when the specific state changes or
     when refresh() is called.
     */
    func test03_playing_Select() throws {
        
        let test = TestYbridControl(ybridDemoEndpoint, listener: listener)
        test.playing() { (ybrid:YbridControl) in
            
            ybrid.select()
            usleep(10_000) /// because the listener notifies asyncronously it *may* take some millis
        }
        
        XCTAssertEqual(listener.services.count, 1, "YbridControlListener.serviceChanged(...) should have been called on refresh, but was \(listener.services.count)")
        
        if let services = listener.services.first  {
            XCTAssertEqual(services.count, 0)
        } else {
            XCTFail()
        }
        
        let expectedOffsets = 2...4
        XCTAssertTrue(expectedOffsets.contains(listener.offsets.count), "YbridControlListener.offsetToLiveChanged(...) should have been called \(expectedOffsets), but was \(listener.offsets.count), \(listener.offsets)")
        
        let expectedSwapCalls = 2...3
        XCTAssertTrue(expectedSwapCalls.contains(listener.swaps.count), "YbridControlListener.swapsChanged(...) should have been called \(expectedSwapCalls) times, but was \(listener.swaps.count)")
        
        XCTAssertGreaterThanOrEqual( listener.metadatas.count, 2, "YbridControlListener.metadataChanged(...) should be called at least twice, but was \(listener.metadatas.count)")
    }

    
    func test04_stopped_maxBitRate_TakesEffekt() throws {
        
        let test = TestYbridControl(ybridDemoEndpoint, listener: listener)
        test.stopped() { (ybrid:YbridControl) in

            XCTAssertNil(self.listener.maxBitRate)
            
            ybrid.maxBitRate(to: 32_000)
            sleep(1)
            XCTAssertEqual(32_000, self.listener.maxBitRate)
            
            ybrid.play()
            sleep(4)
            XCTAssertEqual(32_000, self.listener.maxBitRate)
            
            sleep(4)
            
            ybrid.stop()
            sleep(1)
        }

    }
    

    func test05_playing_ChangeBitRate() throws {
        
        let test = TestYbridControl(ybridDemoEndpoint, listener: listener)
        test.playing() { (ybrid) in
            
            sleep(1)
            XCTAssertEqual(-1, self.listener.maxBitRate)
            
            ybrid.maxBitRate(to:32_000)
            sleep(1)
            XCTAssertEqual(32_000, self.listener.maxBitRate)
            
            ybrid.maxBitRate(to:128_000)
            sleep(1)
            XCTAssertEqual(128_000, self.listener.maxBitRate)
            
            ybrid.maxBitRate(to:192_000)
            sleep(1)
            XCTAssertEqual(192_000, self.listener.maxBitRate)
            
            sleep(4)
        }
    }
}

