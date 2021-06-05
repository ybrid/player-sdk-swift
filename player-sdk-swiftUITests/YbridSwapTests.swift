//
// YbridSwapTests.swift
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

class YbridSwapTests: XCTestCase {

    var player:YbridControl?
    let ybridPlayerListener = TestYbridPlayerListener()
    var semaphore:DispatchSemaphore?
    
    let poller = Poller()
    override func setUpWithError() throws {
        // don't log additional debug information in this tests
        Logger.verbose = true
        ybridPlayerListener.reset()
        semaphore = DispatchSemaphore(value: 0)
    }
    
    override func tearDownWithError() throws {


    }
    

    func test01_SwapItem() throws {
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: ybridPlayerListener,
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                poller.wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
                let titleMain = ybridPlayerListener.metadatas.last?.displayTitle
                print("title= \(titleMain ?? "(nil)")")
                
                ybridControl.swapItem()
                _ = poller.wait(max: 10) {
                    let titleSwapped = ybridPlayerListener.metadatas.last?.displayTitle
                    print("title=\(titleSwapped ?? "(nil)")")
                    return titleMain != titleSwapped
                }
                
                ybridControl.swapToMainItem()
                _ = poller.wait(max: 10) {
                    let titleSwapped = ybridPlayerListener.metadatas.last?.displayTitle
                    print("title=\(titleSwapped ?? "(nil)")")
                    return titleMain == titleSwapped
                }
                
                ybridControl.stop()
                poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        let titles:[String] =
        ybridPlayerListener.metadatas.map{ $0.displayTitle ?? "(nil)"}
        print( "titles were \(titles)")
        
        XCTAssertGreaterThanOrEqual(ybridPlayerListener.metadatas.count, 3)
    }

    func test02_SwapService() throws {
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: ybridPlayerListener,
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                poller.wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                let mainService = ybridPlayerListener.metadatas.last?.serviceId
                sleep(2)
                
                ybridControl.swapService(to:"ad-injection-demo")
                _ = poller.wait(max: 10) {
                    let serviceSwapped = ybridPlayerListener.metadatas.last?.serviceId
                    print("service=\(serviceSwapped ?? "(nil)")")
                    return serviceSwapped != mainService
                }
                sleep(2)
                
                         
                ybridControl.stop()
                poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        let services:[String] =
        ybridPlayerListener.metadatas.map{ $0.serviceId ?? "(nil)"}
        print( "services were \(services)")
        
        XCTAssertEqual(services.count, 3)
    }

    
}

class Poller {
    
    
    
    func wait(_ control:YbridControl, until:PlaybackState, maxSeconds:Int) {
        let took = wait(max: maxSeconds) {
            return control.state == until
        }
        XCTAssertLessThanOrEqual(took, maxSeconds, "not \(until) within \(maxSeconds) s")
    }

    func wait(max maxSeconds:Int, until:() -> (Bool)) -> Int {
        var seconds = 0
        while !until() && seconds <= maxSeconds {
            sleep(1)
            seconds += 1
        }
        XCTAssertTrue(until(), "condition not satisfied within \(maxSeconds) s")
        return seconds
    }

    
    
}


