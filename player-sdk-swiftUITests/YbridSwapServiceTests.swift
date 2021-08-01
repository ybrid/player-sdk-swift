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
    let epCanSwapService = ybridDemoEndpoint

    var semaphore:DispatchSemaphore?
    var testSwapServiceControl:TestYbridControl?
    override func setUpWithError() throws {
        semaphore = DispatchSemaphore(value: 0)
        testSwapServiceControl = TestYbridControl(ybridSwr3Endpoint, listener: listener)
    }
    override func tearDownWithError() throws {
        listener.reset()
    }
    
    func test01_AvailableServices_BeforePlay() throws {
        XCTAssertEqual(0, listener.services.count)
        testSwapServiceControl!.stopped{ (ybridControl) in
            sleep(1) // the listener is notified asynchronously
        }

        checkErrors(expectedErrors: 0)
        XCTAssertEqual(1,listener.services.count)
        guard listener.services.count > 0 else {
            XCTFail("no changed swaps"); return
        }
        XCTAssertEqual(6,listener.services[0].count)
        
        XCTAssertEqual(0,listener.metadatas.count)
    }
    
    func test02_BeforePlay_AudioCallbackCalled() throws {
        Logger.verbose = true
        XCTAssertEqual(0,listener.services.count)
        testSwapServiceControl!.stopped { [self] (ybridControl) in
            
            var carriedOut = false
            ybridControl.swapService(to: "swr-raka09") { (audioChanged) in
                carriedOut = audioChanged
            }
            _ = poller.wait(max: 1) {
                carriedOut == true
            }
            XCTAssertTrue(carriedOut, "swap was not carried out")
        }
        
        checkErrors(expectedErrors: 0)
        
        XCTAssertEqual(listener.services.count, 2)
        guard listener.services.count > 0 else {
            XCTFail("no changed swaps"); return
        }
        XCTAssertEqual(listener.services[0].count, 6)
        
        let services:[String] =
            listener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print("services were \(services)")
    }
    
    func test03_BeforePlay_ChagedButDoesNotTakeEffekt__fails() throws {
        Logger.verbose = true
        XCTAssertEqual(listener.services.count, 0)
        testSwapServiceControl!.stopped { [self] (ybridControl) in

            var carriedOut = false
            ybridControl.swapService(to: "swr-raka09") { (success) in
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
                return serviceSwapped?.identifier == "swr-raka09"
            }
        }

        checkErrors(expectedErrors: 0)
        
        let servicesCalls = listener.services.count
        XCTAssertEqual(servicesCalls, 1)
        guard servicesCalls > 0 else {
            return
        }
        XCTAssertEqual(listener.services[0].count, 6)
        
        let services:[String] =
            listener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print("services were \(services)")
        
        XCTAssertGreaterThanOrEqual(listener.metadatas.count, 1)
        XCTAssertEqual("swr3-live",  listener.metadatas.first?.activeService?.identifier)
        XCTAssertEqual("swr3-live",  listener.metadatas.last?.activeService?.identifier)
    }
    
    func test04_OnPlay_ActiveServiceInNextMetadata() throws {
        testSwapServiceControl!.playing{ [self] (ybridControl) in

            let mainService = listener.metadatas.last?.activeService
            
            ybridControl.swapService(to:"swr-raka09")
            _ = poller.wait(max: Int(YbridSwapServiceTests.maxAudioComplete)) {
                let serviceSwapped = listener.metadatas.last?.activeService
                print("service=\(String(describing: serviceSwapped))")
                return serviceSwapped?.identifier != mainService?.identifier
            }
            
            ybridControl.stop()
            poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
            
        }

        checkErrors(expectedErrors: 0)
        
        let services:[String] =
            listener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print( "services were \(services)")
        
        XCTAssertGreaterThanOrEqual(services.count, 2, "should be 2 different active services, but were \(services.count)")
    }
    
    func test05_AfterStop_TakesEffekt() throws {
        XCTAssertEqual(listener.services.count, 0)
        testSwapServiceControl!.playing{ [self] (ybridControl) in
            
            ybridControl.stop()
            poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
            
            var carriedOut = false
            ybridControl.swapService(to: "swr-raka09") { (success) in
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
                return serviceSwapped?.identifier == "swr-raka09"
            }
        }

        checkErrors(expectedErrors: 0)
        
        XCTAssertEqual(listener.services.count, 2)
        listener.services.forEach{ XCTAssertEqual( $0.count, 6) }
        
        
        let services:[String] =
            listener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print( "services were \(services)")
        
        XCTAssertEqual("swr3-live",  listener.metadatas.first?.activeService?.identifier)
        XCTAssertEqual("swr-raka09",  listener.metadatas.last?.activeService?.identifier)
    }
    
    // MARK: using audio complete
    
   
    func test11_Play_SwapComplete_ok() throws {
        
        let actionTraces = ActionsTrace()
        testSwapServiceControl!.playing{ [self] (ybrid) in
            actionTraces.append( testSwapServiceControl!.swapServiceSynced(to: "swr-raka06") )
        }
        
        checkErrors(expectedErrors: 0)
        actionTraces.check(confirm: 1, maxDuration: YbridSwapServiceTests.maxAudioComplete)
    }
    
    func test12_SwapToSelf_NoSwap() throws {
        
        let actionTraces = ActionsTrace()
        testSwapServiceControl!.playing{ [self] (ybrid) in
            actionTraces.append( testSwapServiceControl!.swapServiceSynced(to: "swr3-live") )
        }

        checkErrors(expectedErrors: 1)
        actionTraces.check(confirm: 1, maxDuration: 1.0)
    }
    
    // During some ads or spots swapping service is denied, for example
    // "Moin, Gerd hier. Ich steh' mit meinem 40-Tonner auf'm Rastplatz..."
    func test13_SwapFromAd_NoSwap() throws {
        
        let actionTraces = ActionsTrace()
        let test = TestYbridControl(ybridAdDemoEndpoint, listener: listener)
        test.playing{ (ybrid) in
            actionTraces.append( test.swapServiceSynced(to: "adaptive-demo", maxWait: 6.0) )
            actionTraces.check(confirm: 1, mustBeCompleted:false, maxDuration: 2.0)
        }

        checkErrors(expectedErrors: 0)
        actionTraces.check(confirm: 1, mustBeCompleted:true, maxDuration: 6.5)
    }
    
  
       
    func test14_SwapBackFromSwapped_InTime() throws {
        
        let actionTraces = ActionsTrace()
        testSwapServiceControl!.playing{ [self] (ybrid) in
            actionTraces.append( testSwapServiceControl!.swapServiceSynced(to: "swr-raka09", maxWait: 15.0) )
            actionTraces.append( testSwapServiceControl!.swapServiceSynced(to: "swr3-live", maxWait: 15.0) )
        }

        checkErrors(expectedErrors: 0)
        actionTraces.check(confirm: 2, maxDuration: YbridSwapServiceTests.maxAudioComplete)
    }
  
    func test15_SwapSwapped__fails() throws {
        
        let actionTraces = ActionsTrace()
        testSwapServiceControl!.playing{ [self] (ybrid) in
            actionTraces.append( testSwapServiceControl!.swapServiceSynced(to: "swr-raka09", maxWait: 15.0) )
            actionTraces.append( testSwapServiceControl!.swapServiceSynced(to: "swr-raka05", maxWait: 20.0) )
        }

        checkErrors(expectedErrors: 0)
        actionTraces.check(confirm: 2, maxDuration: YbridSwapServiceTests.maxAudioComplete)
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

