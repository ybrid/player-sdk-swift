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
    var actions:[ActionTrace] = []
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
        XCTAssertEqual(1,listener.services.count)
        XCTAssertEqual(2,listener.services[0].count)
        
        XCTAssertEqual(0,listener.metadatas.count)
    }
    
    func test02_BeforePlay_AudioCallbackIsCalled() throws {
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
                _ = poller.wait(max: 10) {
                    carriedOut == true
                }
                XCTAssertTrue(carriedOut, "swap was not carried out")
            
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertEqual(1,listener.services.count)
        XCTAssertEqual(2,listener.services[0].count)
        
        let services:[String] =
            listener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print("services were \(services)")
    }
    
    func test03_BeforePlay_ChagedButDoesNotTakeEffekt__NotYet() throws {
        Logger.verbose = true
        XCTAssertEqual(0,listener.services.count)
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: listener,
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
                    let serviceSwapped = listener.metadatas.last?.activeService
                    print("service=\(String(describing: serviceSwapped))")
                    return serviceSwapped?.identifier == "ad-injection-demo"
                }
                
                ybridControl.stop()
                poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertEqual(1,listener.services.count)
        XCTAssertEqual(2,listener.services[0].count)
        
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
                _ = poller.wait(max: 10) {
                    let serviceSwapped = listener.metadatas.last?.activeService
                    print("service=\(String(describing: serviceSwapped))")
                    return serviceSwapped?.identifier != mainService?.identifier
                }
                         
                ybridControl.stop()
                poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        let services:[String] =
            listener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print( "services were \(services)")
        
        XCTAssertGreaterThanOrEqual(services.count, 3, "should be 3 service changes, but were \(services.count)")
    }
    
    func test05_AfterStop_TakesEffekt() throws {
        XCTAssertEqual(0,listener.services.count)
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
                ybridControl.swapService(to: "ad-injection-demo") { (changed) in
                    carriedOut = changed
                }
                _ = poller.wait(max: 10) {
                    carriedOut == true
                }
                XCTAssertTrue(carriedOut, "swap was not carried out")

                ybridControl.play()
                _ = poller.wait(max: 10) {
                    let serviceSwapped = listener.metadatas.last?.activeService
                    print("service=\(String(describing: serviceSwapped))")
                    return serviceSwapped?.identifier == "ad-injection-demo"
                }
                
                ybridControl.stop()
                poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertEqual(1,listener.services.count)
        XCTAssertEqual(2,listener.services[0].count)
        
        let services:[String] =
            listener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print( "services were \(services)")
        
        XCTAssertEqual("adaptive-demo",  listener.metadatas.first?.activeService?.identifier)
        XCTAssertEqual("ad-injection-demo",  listener.metadatas.last?.activeService?.identifier)
    }
    
    
    func test11_PlayDemo_AudioCallback_ok() throws {
        _ = try playAndSwapService(ybridDemoEndpoint, to: "ad-injection-demo")
        let swapsTook = checkTraces(expectedActions: 1, expectedErrors: 0)
        swapsTook.forEach{
            let swapTook = $0; let maxSwap = YbridSwapServiceTests.maxAudioComplete
            XCTAssertLessThan(swapTook, maxSwap, "swapping service should take less than \(maxSwap.S), took \(swapTook.S)")
        }
    }
    
    func test12_PlaySwr3_AudioCallback_ok() throws {
        try playAndSwapService(ybridSwr3Endpoint, to: "swr-raka06")
        let swapsTook = checkTraces(expectedActions: 1, expectedErrors: 0)
        swapsTook.forEach{
            let swapTook = $0; let maxSwap = YbridSwapServiceTests.maxAudioComplete
            XCTAssertLessThan(swapTook, maxSwap, "swapping service should take less than \(maxSwap.S), took \(swapTook.S)")
        }
    }
    
    func test13_SwapToSelfComplete_IcyTriggerOk() throws {
        try playAndSwapService(ybridDemoEndpoint, to: "adaptive-demo")
        let swapsTook = checkTraces(expectedActions: 1, expectedErrors: 1)
        swapsTook.forEach{
            let swapTook = $0; let maxNotSwap = 1.0
            XCTAssertLessThan(swapTook, maxNotSwap, "swapping service should take less than \(maxNotSwap.S), took \(swapTook.S)")
        }
    }
    
    func test14_SwapSwappedServiceComplete_Demo_IcyTriggerInTime() throws {
        try playAndSwapSwappedService(ybridDemoEndpoint, first: "ad-injection-demo", second: "adaptive-demo")
        let swapsTook = checkTraces(expectedActions: 2, expectedErrors: 0)
        swapsTook.forEach { (swapTook) in
            let maxSwap = YbridSwapServiceTests.maxAudioComplete
            XCTAssertLessThan(swapTook, maxSwap, "swapping service should take less than \(maxSwap.S), took \(swapTook.S)")
        }
    }
    
    // there are ads where swap service is delayed until finished, for example
    // "Moin, Gerd hier. Ich steh' mit meinem 40-Tonner auf'm Rastplatz..."
    func test15_SwapSwappedServiceComplete_AdDemo_IcyTriggerInTime() throws {
        try playAndSwapSwappedService(ybridAdDemoEndpoint, first: "adaptive-demo", second: "ad-injection-demo")
        let swapsTook = checkTraces(expectedActions: 2, expectedErrors: 0)
        swapsTook.forEach { (swapTook) in
            let maxSwap = YbridSwapServiceTests.maxAudioComplete
            XCTAssertLessThan(swapTook, maxSwap, "swapping service should take less than \(maxSwap.S), took \(swapTook.S)")
        }
    }
    
    func test16_SwapBackFromSwappedService_Swr3_IcyTriggerOk() throws {
        try playAndSwapSwappedService(ybridSwr3Endpoint, first: "swr-raka09", second: "swr3-live")
        let swapsTook = checkTraces(expectedActions: 2, expectedErrors: 0)
        swapsTook.forEach { (swapTook) in
            let maxSwap = YbridSwapServiceTests.maxAudioComplete
            XCTAssertLessThan(swapTook, maxSwap, "swapping service should take less than \(maxSwap.S), took \(swapTook.S)")
        }
    }
  
    func test17_SwapSwappedService_Swr3_IcyTriggerTooLate() throws {
        try playAndSwapSwappedService(ybridSwr3Endpoint, first: "swr-raka09", second: "swr-raka05")
        let swapsTook = checkTraces(expectedActions: 2, expectedErrors: 0)
        swapsTook.forEach { (swapTook) in
            let maxSwap = YbridSwapServiceTests.maxAudioComplete
            XCTAssertLessThan(swapTook, maxSwap, "swapping service should take less than \(maxSwap.S), took \(swapTook.S)")
        }
    }
    
    
    private func playAndSwapService(_ endpoint:MediaEndpoint, to serviceId:String) throws {
        
        try playingYbridControl(endpoint) { [self] (ybridControl) in
           let actionSemaphore = DispatchSemaphore(value: 0)
           
           var trace1 = ActionTrace(triggered: Date())
            ybridControl.swapService(to: serviceId) { (changed) in
                trace1.completed = Date()
                trace1.acted = changed
                actions.append(trace1)
                Logger.testing.notice("***** audio complete ***** \(changed ? "":"not ")swapping service")
                sleep(6)
        
                actionSemaphore.signal()
            }
           _ = actionSemaphore.wait(timeout: .distantFuture)
       }
    }


    private func playAndSwapSwappedService(_ endpoint:MediaEndpoint, first serviceId1:String, second serviceId2:String) throws {
        try playingYbridControl(endpoint) { [self] (ybridControl) in
           let actionSemaphore = DispatchSemaphore(value: 0)
           
           var trace1 = ActionTrace(triggered: Date())
            ybridControl.swapService(to: serviceId1) { (changed) in
                trace1.completed = Date()
                trace1.acted = changed
                actions.append(trace1)
                Logger.testing.notice( "***** audio complete ***** \(changed ? "":"not ")swapping service")
                sleep(2)
                
                var trace2 = ActionTrace(triggered: Date())
                    ybridControl.swapService(to: serviceId2) { (changed) in
                        trace2.completed = Date()
                        trace2.acted = changed
                        actions.append(trace2)
                        Logger.testing.notice( "***** audio complete ***** \(changed ? "":"not ")swapping service")
                        sleep(2)
         
                        actionSemaphore.signal()
                    }
            }
            _ = actionSemaphore.wait(timeout: .distantFuture)
        }
    }
    
    // generic Control playing, executing actionSync and stopping control
    private func playingYbridControl(_ endpoint:MediaEndpoint, actionSync: @escaping (YbridControl)->() ) throws {

        try AudioPlayer.open(for: endpoint, listener: listener,
             playbackControl: { (ctrl) in self.semaphore?.signal()
                XCTFail(); return },
             ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                poller.wait(ybridControl, until:PlaybackState.playing, maxSeconds:10)
                
                actionSync(ybridControl)
                
                ybridControl.stop()
                sleep(1)
                ybridControl.close()
                semaphore?.signal()
             })
        _ = semaphore?.wait(timeout: .distantFuture)
    }
    
    struct ActionTrace {
        var triggered:Date? = nil
        var completed:Date? = nil
        var acted:Bool = false
    }
    
    private func checkTraces(expectedActions:Int, expectedErrors:Int) -> [TimeInterval] {
        guard listener.errors.count == expectedErrors else {
            XCTFail("\(expectedErrors) errors expected, but were \(listener.errors.count)")
            listener.errors.forEach { (err) in
                let errMessage = err.localizedDescription
                XCTFail("error is \(errMessage)")
            }
            return []
        }
        
        guard actions.count == expectedActions else {
            XCTFail("expecting \(expectedActions) completed actions, but were \(actions.count)")
            return []
        }
        
        let actionsTook:[TimeInterval] = actions.filter{
             return $0.triggered != nil && $0.completed != nil
        }.map{
            let actionTookS = $0.completed!.timeIntervalSince($0.triggered!)
            Logger.testing.debug("\($0.acted ? "" : "not ")winding took \(actionTookS.S)")
            return actionTookS
        }
        return actionsTook
    }

}
