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

    var control:YbridControl?
    let ybridPlayerListener = TestYbridPlayerListener()
    var semaphore:DispatchSemaphore?
    
    let poller = Poller()
    override func setUpWithError() throws {
        // don't log additional debug information in this tests
        Logger.verbose = false
        ybridPlayerListener.reset()
        semaphore = DispatchSemaphore(value: 0)
    }
    
    override func tearDownWithError() throws {
        let errors = ybridPlayerListener.errors.map{ $0.localizedDescription }
        print( "errors were \(errors)")
    }

    func test01_SwapsLeft_WithoutPlaying_0() throws {
        Logger.verbose = true
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: ybridPlayerListener,
                playbackControl: { [self] (control) in
                    XCTFail("ybridControl expected");semaphore?.signal()
                },
                ybridControl: { [self] (ybridControl) in
                    sleep(1) // the listener is notified asynchronously
                    XCTAssertEqual(0, ybridPlayerListener.swapsLeft, "\(String(describing: ybridPlayerListener.swapsLeft)) swaps are left.")
                    
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        let titles:[String] =
        ybridPlayerListener.metadatas.map{ $0.displayTitle ?? "(nil)"}
        print( "titles were \(titles)")
    }

    
    func test02_SwapItem_WhilePlaying() throws {
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: ybridPlayerListener,
                playbackControl: { [self] (control) in
                    XCTFail("ybridControl expected");semaphore?.signal()
                },
                ybridControl: { [self] (ybridControl) in
                defer {
                    ybridControl.stop()
                    poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                    semaphore?.signal()
                }
                    
                ybridControl.play()
                poller.wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                    
                guard let swaps = ybridPlayerListener.swapsLeft, swaps != 0 else {
                    XCTFail("currently no swaps left. Execute test later"); return
                }
                print("\(swaps) swaps are left")
                    
                guard let titleMain = ybridPlayerListener.metadatas.last?.displayTitle else {
                    XCTFail("must have recieved metadata"); return
                }
                print("title main =\(titleMain)")
                
                var titleSwapped:String?
                    ybridControl.swapItem()
                _ = poller.wait(max: 10) {
                    guard let swapped = ybridPlayerListener.metadatas.last?.displayTitle else {
                        return false
                    }
                    titleSwapped = swapped
                    print("title swapped =\(titleSwapped!)")
                    return titleMain != titleSwapped!
                }
                
                ybridControl.swapItem()
                _ = poller.wait(max: 10) {
                    guard let titleSwapped2 = ybridPlayerListener.metadatas.last?.displayTitle else {
                        return false
                    }
                    print("title swapped =\(titleSwapped2)")
                    return titleSwapped2 != titleSwapped
                }

               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        let titles:[String] =
        ybridPlayerListener.metadatas.map{ $0.displayTitle ?? "(nil)"}
        print( "titles were \(titles)")
        
        XCTAssertTrue((3...4).contains(ybridPlayerListener.metadatas.count), "should be 3 (4 if item changed) metadata changes, but were \(ybridPlayerListener.metadatas.count)")
    }

    func test03_SwapItem_CarriedOutCallbackIsCalled() throws {
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: ybridPlayerListener,
                playbackControl: { [self] (control) in
                    XCTFail("ybridControl expected");semaphore?.signal()
                },
                ybridControl: { [self] (ybridControl) in
                defer {
                    ybridControl.stop()
                    poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                    semaphore?.signal()
                }
                ybridControl.play()
                poller.wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
              
                guard let swaps = ybridPlayerListener.swapsLeft, swaps != 0 else {
                    XCTFail("currently no swaps left. Execute test later")
                    return
                }
                print("\(swaps) swaps are left")
                    
                var carriedOut = false
                    ybridControl.swapItem { (audioChanged) in
                    carriedOut = audioChanged
                }
                _ = poller.wait(max: 10) {
                    carriedOut == true
                }
                XCTAssertTrue(carriedOut, "swap was not carried out")
                sleep(2)
                    
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        let titles:[String] =
        ybridPlayerListener.metadatas.map{ $0.displayTitle ?? "(nil)"}
        print( "titles were \(titles)")
        
        let differentTitles = Set(titles)
        print( "different titles were \(differentTitles)")
        XCTAssertEqual(2, differentTitles.count)
        
        XCTAssertTrue((2...3).contains(ybridPlayerListener.metadatas.count), "should be 2 (3 if item changed) metadata changes, but were \(ybridPlayerListener.metadatas.count)")
    }

    
    func test04_AvailableServices_BeforePlay() throws {
        XCTAssertEqual(0,ybridPlayerListener.services.count)
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: ybridPlayerListener,
               playbackControl: { [self] (control) in
                    XCTFail("ybridControl expected"); semaphore?.signal()
               },
               ybridControl: { [self] (ybridControl) in
                    sleep(1) // the listener is notified asynchronously
                    semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        XCTAssertEqual(1,ybridPlayerListener.services.count)
        XCTAssertEqual(2,ybridPlayerListener.services[0].count)
        
        XCTAssertEqual(0,ybridPlayerListener.metadatas.count)
    }
    
    func test05_SwapService_BeforePlay_CarriedOutIsCalled() throws {
        Logger.verbose = true
        XCTAssertEqual(0,ybridPlayerListener.services.count)
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: ybridPlayerListener,
               playbackControl: { [self] (control) in
                     XCTFail("ybridControl expected"); semaphore?.signal()
               },
               ybridControl: { [self] (ybridControl) in

                var carriedOut = false
                ybridControl.swapService(to: "ad-injection-demo") { (audioChanged) in
                    carriedOut = audioChanged
                }
                _ = poller.wait(max: 10) {
                    carriedOut == true
                }
                XCTAssertTrue(carriedOut, "swap was not carried out")
            
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertEqual(1,ybridPlayerListener.services.count)
        XCTAssertEqual(2,ybridPlayerListener.services[0].count)
        
        let services:[String] =
            ybridPlayerListener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print("services were \(services)")
    }

    func test06_SwapService_BeforePlay_ChagedButDoesNotTakeEffekt__NotYet() throws {
        Logger.verbose = true
        XCTAssertEqual(0,ybridPlayerListener.services.count)
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: ybridPlayerListener,
               playbackControl: { [self] (control) in
                     XCTFail("ybridControl expected"); semaphore?.signal()
               },
               ybridControl: { [self] (ybridControl) in

                var carriedOut = false
                ybridControl.swapService(to: "ad-injection-demo") { (changed) in
                    carriedOut = changed
                }
                _ = poller.wait(max: 10) {
                    carriedOut == true
                }
                XCTAssertTrue(carriedOut, "swap was not carried out")
                
                ybridControl.play()
                _ = poller.wait(max: 6) {
                    let serviceSwapped = ybridPlayerListener.metadatas.last?.activeService
                    print("service=\(String(describing: serviceSwapped))")
                    return serviceSwapped?.identifier == "ad-injection-demo"
                }
                
                ybridControl.stop()
                poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertEqual(1,ybridPlayerListener.services.count)
        XCTAssertEqual(2,ybridPlayerListener.services[0].count)
        
        let services:[String] =
            ybridPlayerListener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print("services were \(services)")
        
        XCTAssertGreaterThanOrEqual(ybridPlayerListener.metadatas.count, 1)
        XCTAssertEqual("ad-injection-demo",  ybridPlayerListener.metadatas.first?.activeService?.identifier)
        XCTAssertEqual("ad-injection-demo",  ybridPlayerListener.metadatas.last?.activeService?.identifier)
    }

    func test07_SwapService_OnPlay_ActiveServiceInNextMetadata() throws {
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: ybridPlayerListener,
               playbackControl: { [self] (control) in
                     XCTFail("ybridControl expected");semaphore?.signal()
               },
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                poller.wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                let mainService = ybridPlayerListener.metadatas.last?.activeService
                
                ybridControl.swapService(to:"ad-injection-demo")
                _ = poller.wait(max: 10) {
                    let serviceSwapped = ybridPlayerListener.metadatas.last?.activeService
                    print("service=\(String(describing: serviceSwapped))")
                    return serviceSwapped?.identifier != mainService?.identifier
                }
                         
                ybridControl.stop()
                poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        let services:[String] =
            ybridPlayerListener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print( "services were \(services)")
        
        XCTAssertEqual(services.count, 3, "should be 3 service changes, but were \(services.count)")
    }
    
    func test08_SwapService_AfterStop_TakesEffekt() throws {
        XCTAssertEqual(0,ybridPlayerListener.services.count)
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: ybridPlayerListener,
               playbackControl: { [self] (control) in
                     XCTFail("ybridControl expected"); semaphore?.signal()
               },
               ybridControl: { [self] (ybridControl) in

                ybridControl.play()
                poller.wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                
                ybridControl.stop()
                poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                var carriedOut = false
                ybridControl.swapService(to: "ad-injection-demo") { (changed) in
                    carriedOut = changed
                }
                _ = poller.wait(max: 10) {
                    carriedOut == true
                }
                XCTAssertTrue(carriedOut, "swap was not carried out")
                
                ybridControl.play()
                _ = poller.wait(max: 10) {
                    let serviceSwapped = ybridPlayerListener.metadatas.last?.activeService
                    print("service=\(String(describing: serviceSwapped))")
                    return serviceSwapped?.identifier == "ad-injection-demo"
                }
                
                ybridControl.stop()
                poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertEqual(1,ybridPlayerListener.services.count)
        XCTAssertEqual(2,ybridPlayerListener.services[0].count)
        
        let services:[String] =
            ybridPlayerListener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print( "services were \(services)")
        
        XCTAssertEqual("adaptive-demo",  ybridPlayerListener.metadatas.first?.activeService?.identifier)
        XCTAssertEqual("ad-injection-demo",  ybridPlayerListener.metadatas.last?.activeService?.identifier)
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
