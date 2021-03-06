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
    var ybridControl:TestYbridControl?
    override func setUpWithError() throws {
        listener.reset()
        ybridControl = TestYbridControl(ybridSwr3Endpoint, listener: listener)
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
        
        guard let ybridControl = ybridControl else {
            XCTFail("cannot use ybrid control.")
            return
        }
        
        ybridControl.stopped() { (ybridControl) in
//            usleep(10_000) /// because the listener notifies asyncronously it *may* take some millis
        }
        
        XCTAssertEqual(listener.services.count, 1, "YbridControlListener.serviceChanged(...) should have been called once, but was \(listener.services.count)")
        
        XCTAssertGreaterThanOrEqual(listener.offsets.count, 1, "YbridControlListener.offsetToLiveChanged(...) should have been called at least once, but was \(listener.offsets.count), \(listener.offsets)")
        
        XCTAssertEqual(listener.swaps.count, 1, "YbridControlListener.swapsChanged(...) should have been called once, but was \(listener.swaps.count)")

        XCTAssertEqual(listener.metadatas.count, 0, "YbridControlListener.metadataChanged(...) should not be called, but was \(listener.metadatas.count)")
    }
    
    /*
     The listeners methods are called when the specific state changes or
     when refresh() is called.
     */
    func test02_Stopped_Refresh() {
        
        guard let ybridControl = ybridControl else {
            XCTFail("cannot use ybrid control.")
            return
        }
        
        ybridControl.stopped() { (ybridControl) in
            
            ybridControl.refresh()
            usleep(10_000) /// because the listener is notified asyncronously it *may* take some millis
        }
        
        XCTAssertEqual(listener.services.count, 2, "YbridControlListener.serviceChanged(...) should have been called twice, but was \(listener.services.count)")
        
        XCTAssertTrue((2...3).contains(listener.offsets.count), "YbridControlListener.offsetToLiveChanged(...) should have been called \(2...3), but was \(listener.offsets.count), \(listener.offsets)")
        
        XCTAssertEqual(listener.swaps.count, 2,"YbridControlListener.swapsChanged(...) should have been called twice, but was \(listener.swaps.count)")

        XCTAssertEqual(listener.metadatas.count, 1, "YbridControlListener.metadataChanged(...) should not be called once, but was \(listener.metadatas.count)")
    }

    
    /*
     The listener is notified of ybrid states in the beginning of the session.
     The listeners methods are called when the specific state changes or
     when refresh() is called.
     */
    func test03_Playing_Refresh() throws {
        
        guard let ybridControl = ybridControl else {
            XCTFail("cannot use ybrid control.")
            return
        }
        
        ybridControl.playing() { (ybridControl) in
            
            ybridControl.refresh()
            usleep(10_000) /// because the listener notifies asyncronously it *may* take some millis
        }
        
        XCTAssertEqual(2, listener.services.count, "YbridControlListener.serviceChanged(...) should have been called twice, but was \(listener.services.count)")
        
        let expectedRange = 2...5
        XCTAssertTrue(expectedRange.contains(listener.offsets.count), "YbridControlListener.offsetToLiveChanged(...) should have been called \(expectedRange), but was \(listener.offsets.count), \(listener.offsets)")
        
        XCTAssertEqual(2, listener.swaps.count, "YbridControlListener.swapsChanged(...) should have been called twice, but was \(listener.swaps.count)")
        
        XCTAssertGreaterThanOrEqual( listener.metadatas.count, 2, "YbridControlListener.metadataChanged(...) should be called at least twice, but was \(listener.metadatas.count)")
    }

}

class TestYbridControl {
    let poller = Poller()
    let endpoint:MediaEndpoint
    let listener:YbridControlListener
    let semaphore:DispatchSemaphore
    init(_ endpoint:MediaEndpoint, listener:YbridControlListener, whenClosed extSemaphore:DispatchSemaphore? = nil) {
        self.endpoint = endpoint
        self.listener = listener
        if let semaphore = extSemaphore {
            self.semaphore = semaphore
        } else {
            self.semaphore = DispatchSemaphore(value: 0)
        }
    }
    
    func playing( action: @escaping (YbridControl)->() ) {
        do {
            try AudioPlayer.open(for: endpoint, listener: listener,
                 playbackControl: { (ctrl) in self.semaphore.signal()
                    XCTFail(); return },
                 ybridControl: { [self] (ybridControl) in
                    
                    ybridControl.play()
                    poller.wait(ybridControl, until:PlaybackState.playing, maxSeconds:10)
                    
                    action(ybridControl)
                    
                    ybridControl.stop()
                    poller.wait(ybridControl, until:PlaybackState.stopped, maxSeconds:2)
                    ybridControl.close()
                    semaphore.signal()
                 })
        } catch {
            XCTFail("no player. Something went wrong");
            semaphore.signal(); return
        }
        _ = semaphore.wait(timeout: .distantFuture)
    }
    
    func stopped( action: @escaping (YbridControl)->() ) {
        do {
            try AudioPlayer.open(for: endpoint, listener: listener,
                 playbackControl: { (ctrl) in self.semaphore.signal()
                    XCTFail(); return },
                 ybridControl: { [self] (ybridControl) in
                    
                    action(ybridControl)
                    
                    ybridControl.close()
                    semaphore.signal()
                 })
        } catch {
            XCTFail("no player. Something went wrong");
            semaphore.signal(); return
        }
        _ = semaphore.wait(timeout: .distantFuture)
    }
}
