//
// YbridSwapServiceTests.swift
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

class YbridSwapServiceTests: XCTestCase {

    static let maxAudioComplete:TimeInterval = 4.0
    var listener = TestYbridPlayerListener()
    let poller = Poller()

    var semaphore:DispatchSemaphore?
    override func setUpWithError() throws {
        semaphore = DispatchSemaphore(value: 0)
        Logger.verbose = false
        listener = TestYbridPlayerListener()
    }
    override func tearDownWithError() throws {
    }
    
    func test01_AvailableServices_BeforePlay() throws {
        XCTAssertEqual(0, listener.services.count)
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: listener,
               playbackControl: { [self] (control) in
                    XCTFail("ybridControl expected"); semaphore?.signal()
               },
               ybridControl: { [self] (ybridControl) in
                    sleep(1) // the listener is notified asynchronously
                    semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        checkErrors(expectedErrors: 0)
        XCTAssertEqual(1,listener.services.count)
        XCTAssertEqual(2,listener.services[0].count)
        
        XCTAssertEqual(0,listener.metadatas.count)
    }
    
    func test02_BeforePlay_AudioCallbackCalled() throws {
        Logger.verbose = true
        XCTAssertEqual(0,listener.services.count)
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: listener,
               playbackControl: { [self] (control) in
                     XCTFail("ybridControl expected"); semaphore?.signal()
               },
               ybridControl: { [self] (ybridControl) in

                var carriedOut = false
                ybridControl.swapService(to: "ad-injection-demo") { (audioChanged) in
                    carriedOut = audioChanged
                }
                _ = poller.wait(max: 1) {
                    carriedOut == true
                }
                XCTAssertTrue(carriedOut, "swap was not carried out")
            
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        checkErrors(expectedErrors: 0)
        
        XCTAssertEqual(listener.services.count, 2)
        XCTAssertEqual(listener.services[0].count, 2)
        
        let services:[String] =
            listener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print("services were \(services)")
    }
    
    func test03_BeforePlay_ChagedButDoesNotTakeEffekt__NotYet() throws {
        Logger.verbose = true
        XCTAssertEqual(listener.services.count, 0)
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: listener,
               playbackControl: { [self] (control) in
                     XCTFail("ybridControl expected"); semaphore?.signal()
               },
               ybridControl: { [self] (ybridControl) in

                var carriedOut = false
                ybridControl.swapService(to: "ad-injection-demo") { (success) in
                    carriedOut = success
                }
                _ = poller.wait(max: 1) {
                    carriedOut == true
                }
                XCTAssertTrue(carriedOut, "swap was not carried out")
                
                ybridControl.play()
                _ = poller.wait(max: 6) {
                    let serviceSwapped = listener.metadatas.last?.activeService
                    print("service=\(String(describing: serviceSwapped))")
                    return serviceSwapped?.identifier == "ad-injection-demo"
                }
                
                ybridControl.stop()
                poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        checkErrors(expectedErrors: 0)
        
        XCTAssertEqual(listener.services.count, 1)
        XCTAssertEqual(listener.services[0].count, 2)
        
        let services:[String] =
            listener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print("services were \(services)")
        
        XCTAssertGreaterThanOrEqual(listener.metadatas.count, 1)
        XCTAssertEqual("ad-injection-demo",  listener.metadatas.first?.activeService?.identifier)
        XCTAssertEqual("ad-injection-demo",  listener.metadatas.last?.activeService?.identifier)
    }
    
    func test04_OnPlay_ActiveServiceInNextMetadata() throws {
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: listener,
               playbackControl: { [self] (control) in
                     XCTFail("ybridControl expected");semaphore?.signal()
               },
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                poller.wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                let mainService = listener.metadatas.last?.activeService
                
                ybridControl.swapService(to:"ad-injection-demo")
                _ = poller.wait(max: Int(YbridSwapServiceTests.maxAudioComplete)) {
                    let serviceSwapped = listener.metadatas.last?.activeService
                    print("service=\(String(describing: serviceSwapped))")
                    return serviceSwapped?.identifier != mainService?.identifier
                }
                         
                ybridControl.stop()
                poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        checkErrors(expectedErrors: 0)
        
        let services:[String] =
            listener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print( "services were \(services)")
        
        XCTAssertGreaterThanOrEqual(services.count, 2, "should be 2 different active services, but were \(services.count)")
    }
    
    func test05_AfterStop_TakesEffekt() throws {
        XCTAssertEqual(listener.services.count, 0)
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: listener,
               playbackControl: { [self] (control) in
                     XCTFail("ybridControl expected"); semaphore?.signal()
               },
               ybridControl: { [self] (ybridControl) in

                ybridControl.play()
                poller.wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                
                ybridControl.stop()
                poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                var carriedOut = false
                ybridControl.swapService(to: "ad-injection-demo") { (success) in
                    carriedOut = success
                }
                _ = poller.wait(max: 1) {
                    carriedOut == true
                }
                XCTAssertTrue(carriedOut, "swap was not carried out")

                ybridControl.play()
                _ = poller.wait(max: 8) {
                    let serviceSwapped = listener.metadatas.last?.activeService
                    print("service=\(String(describing: serviceSwapped))")
                    return serviceSwapped?.identifier == "ad-injection-demo"
                }
                
                ybridControl.stop()
                poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        checkErrors(expectedErrors: 0)
        
        XCTAssertEqual(listener.services.count, 2)
        listener.services.forEach{ XCTAssertEqual( $0.count, 2) }
        
        
        let services:[String] =
            listener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print( "services were \(services)")
        
        XCTAssertEqual("adaptive-demo",  listener.metadatas.first?.activeService?.identifier)
        XCTAssertEqual("ad-injection-demo",  listener.metadatas.last?.activeService?.identifier)
    }
    
    // MARK: using audio complete
    
    func test11_PlayDemo_SwapComplete_ok() throws {
        
        let actionTraces = ActionsTrace()
        TestYbridControl(ybridDemoEndpoint, listener: listener).playing{ (ybrid) in
            actionTraces.append( swapServiceSynced(to: "ad-injection-demo", ybrid) )
        }

        checkErrors(expectedErrors: 0)
        actionTraces.check(expectedActions: 1, maxDuration: YbridSwapServiceTests.maxAudioComplete)
    }
    
    func test12_PlaySwr3_SwapComplete_ok() throws {
        
        let actionTraces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: listener).playing{ (ybrid) in
            actionTraces.append( swapServiceSynced(to: "swr-raka06", ybrid) )
        }
        
        checkErrors(expectedErrors: 0)
        actionTraces.check(expectedActions: 1, maxDuration: YbridSwapServiceTests.maxAudioComplete)
    }
    
    func test13_SwapToSelf_NoSwap() throws {
        
        let actionTraces = ActionsTrace()
        TestYbridControl(ybridDemoEndpoint, listener: listener).playing{ (ybrid) in
            actionTraces.append( swapServiceSynced(to: "adaptive-demo", ybrid) )
        }

        checkErrors(expectedErrors: 1)
        actionTraces.check(expectedActions: 1, maxDuration: 1.0)
    }
    
    // During some ads or spots swapping service is denied, for example
    // "Moin, Gerd hier. Ich steh' mit meinem 40-Tonner auf'm Rastplatz..."
    func test14_SwapFromAd_NoSwap() throws {
        
        let actionTraces = ActionsTrace()
        TestYbridControl(ybridAdDemoEndpoint, listener: listener).playing{ (ybrid) in
            actionTraces.append( swapServiceSynced(to: "adaptive-demo", ybrid, maxWait: 6.0) )
            actionTraces.check(expectedActions: 1, mustBeCompleted:false, maxDuration: 2.0)
        }

        checkErrors(expectedErrors: 0)
        actionTraces.check(expectedActions: 1, mustBeCompleted:true, maxDuration: 6.5)
    }
    
    func test15_SwapBackFromSwappedDemo_InTime() throws {
        
        let actionTraces = ActionsTrace()
        TestYbridControl(ybridDemoEndpoint, listener: listener).playing{ (ybrid) in
            actionTraces.append( swapServiceSynced(to: "ad-injection-demo", ybrid))
            actionTraces.append( swapServiceSynced(to: "adaptive-demo", ybrid))
        }

        checkErrors(expectedErrors: 0)
        actionTraces.check(expectedActions: 2, maxDuration: YbridSwapServiceTests.maxAudioComplete)
    }
       
    func test16_SwapBackFromSwappedSwr3_InTime() throws {
        
        let actionTraces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: listener).playing{ (ybrid) in
            actionTraces.append( swapServiceSynced(to: "swr-raka09", ybrid, maxWait: 15.0) )
            actionTraces.append( swapServiceSynced(to: "swr3-live", ybrid, maxWait: 15.0) )
        }

        checkErrors(expectedErrors: 0)
        actionTraces.check(expectedActions: 2, maxDuration: YbridSwapServiceTests.maxAudioComplete)
    }
  
    func test17_SwapSwappedSwr3_TooLate() throws {
        
        let actionTraces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: listener).playing{ (ybrid) in
            actionTraces.append( swapServiceSynced(to: "swr-raka09", ybrid, maxWait: 15.0) )
            actionTraces.append( swapServiceSynced(to: "swr-raka05", ybrid, maxWait: 20.0) )
        }

        checkErrors(expectedErrors: 0)
        actionTraces.check(expectedActions: 2, maxDuration: YbridSwapServiceTests.maxAudioComplete)
    }
    


    
    private func checkErrors(expectedErrors:Int)  {
        guard listener.errors.count == expectedErrors else {
            XCTFail("\(expectedErrors) errors expected, but were \(listener.errors.count)")
            listener.errors.forEach { (err) in
                let errMessage = err.localizedDescription
                Logger.testing.error("-- error is \(errMessage)")
            }
            return
        }
    }

}

fileprivate func swapServiceSynced(to serviceId:String, _ ybrid:YbridControl, maxWait:TimeInterval? = nil) -> (Trace) {
    let mySema = DispatchSemaphore(value: 0)
    let trace = Trace("swap to \(serviceId)")
    ybrid.swapService(to: serviceId) { (success) in
        swapServiceComplete(success, trace)
        mySema.signal()
    }
    if let maxWait = maxWait {
        _ = mySema.wait(timeout: .now() + maxWait)
    } else {
        _ = mySema.wait(timeout: .distantFuture)
    }
    return trace
}


fileprivate func swapServiceComplete(_ success:Bool,_ trace:Trace) {
   trace.complete(success)
   Logger.testing.notice( "***** audio complete ***** did \(success ? "":"not ")\(trace.name)")
   sleep(3)
}
