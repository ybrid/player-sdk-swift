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
    static let swr3ServicesCount = 7
    let poller = Poller()
    let epCanSwapService = ybridDemoEndpoint
    
    func test01_AvailableServices_BeforePlay() throws {
        let test = TestYbridControl(ybridSwr3Endpoint)
        XCTAssertEqual(0, test.listener.services.count)
        test.stopped{ (ybridControl) in
            sleep(1) // the listener is notified asynchronously
        }

        _ = test.checkErrors(expected: 0)
        XCTAssertEqual(1, test.listener.services.count)
        guard test.listener.services.count > 0 else {
            XCTFail("no changed swaps"); return
        }
        XCTAssertEqual(YbridSwapServiceTests.swr3ServicesCount,
                       test.listener.services[0].count)
        
        XCTAssertEqual(0,test.listener.metadatas.count)
    }
    
    func test02_BeforePlay_AudioCallbackCalled() throws {
        let test = TestYbridControl(ybridSwr3Endpoint)
        XCTAssertEqual(0,test.listener.services.count)
        test.stopped { [self] (ybridControl) in
            
            var carriedOut = false
            test.ybrid?.swapService(to: "swr-raka09") { (audioChanged) in
                carriedOut = audioChanged
            }
            _ = poller.wait(max: 1) {
                carriedOut == true
            }
            XCTAssertTrue(carriedOut, "swap was not carried out")
        }
        
        _ = test.checkErrors(expected: 0)
        
        XCTAssertEqual(test.listener.services.count, 2)
        guard test.listener.services.count > 0 else {
            XCTFail("no changed swaps"); return
        }
        XCTAssertEqual(YbridSwapServiceTests.swr3ServicesCount,
                       test.listener.services[0].count)
        
        let services:[String] =
            test.listener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print("services were \(services)")
    }
    
    func test03_BeforePlay_ChagedButDoesNotTakeEffekt__fails() throws {
        let test = TestYbridControl(ybridSwr3Endpoint)
        XCTAssertEqual(test.listener.services.count, 0)
        test.stopped { [self] (ybridControl) in

            var carriedOut = false
            test.ybrid?.swapService(to: "swr-raka09") { (success) in
                carriedOut = success
            }
            _ = poller.wait(max: 1) {
                carriedOut == true
            }
            XCTAssertTrue(carriedOut, "swap was not carried out")
            
            ybridControl.play()
            _ = poller.wait(max: 6) {
                let serviceSwapped = test.listener.metadatas.last?.activeService
                print("service=\(String(describing: serviceSwapped))")
                return serviceSwapped?.identifier == "swr-raka09"
            }
        }

        _ = test.checkErrors(expected: 0)
        
        let servicesCalls = test.listener.services.count
        XCTAssertEqual(servicesCalls, 1)
        guard servicesCalls > 0 else {
            return
        }
        XCTAssertEqual(YbridSwapServiceTests.swr3ServicesCount,
                       test.listener.services[0].count)
        
        let services:[String] =
            test.listener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print("services were \(services)")
        
        XCTAssertGreaterThanOrEqual(test.listener.metadatas.count, 1)
        XCTAssertEqual("swr3-live",  test.listener.metadatas.first?.activeService?.identifier)
        XCTAssertEqual("swr3-live",  test.listener.metadatas.last?.activeService?.identifier)
    }
    
    func test04_OnPlay_ActiveServiceInNextMetadata() throws {
        let test = TestYbridControl(ybridSwr3Endpoint)
        test.playing{ [self] (ybridControl) in

            let mainService = test.listener.metadatas.last?.activeService
            
            ybridControl.swapService(to:"swr-raka09")
            _ = poller.wait(max: Int(YbridSwapServiceTests.maxAudioComplete)) {
                let serviceSwapped = test.listener.metadatas.last?.activeService
                print("service=\(String(describing: serviceSwapped))")
                return serviceSwapped?.identifier != mainService?.identifier
            }
            
            ybridControl.stop()
            poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
            
        }

        _ = test.checkErrors(expected: 0)
        
        let services:[String] =
            test.listener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print( "services were \(services)")
        
        XCTAssertGreaterThanOrEqual(services.count, 2, "should be 2 different active services, but were \(services.count)")
    }
    
    func test05_AfterStop_TakesEffekt() throws {
        let test = TestYbridControl(ybridSwr3Endpoint)
        XCTAssertEqual(test.listener.services.count, 0)
        test.playing{ [self] (ybridControl) in
            
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
                let serviceSwapped = test.listener.metadatas.last?.activeService
                print("service=\(String(describing: serviceSwapped))")
                return serviceSwapped?.identifier == "swr-raka09"
            }
        }

        _ = test.checkErrors(expected: 0)
        
        XCTAssertEqual(test.listener.services.count, 2)
        test.listener.services.forEach{ XCTAssertEqual( $0.count,
                                                        YbridSwapServiceTests.swr3ServicesCount) }
        
        
        let services:[String] =
            test.listener.metadatas.map{ $0.activeService?.identifier ?? "(nil)"}
        print( "services were \(services)")
        
        XCTAssertEqual("swr3-live",  test.listener.metadatas.first?.activeService?.identifier)
        XCTAssertEqual("swr-raka09",  test.listener.metadatas.last?.activeService?.identifier)
    }
    
    // MARK: using audio complete
    
   
    func test11_Play_SwapComplete_ok() throws {
       let test = TestYbridControl(ybridSwr3Endpoint)
        test.playing{ [self] (ybrid) in
            test.swapServiceSynced(to: "swr-raka06")
        }
        
        _ = test.checkErrors(expected: 0)
            .checkAllActions(confirm: 1, withinS: YbridSwapServiceTests.maxAudioComplete)
    }
    
    func test12_SwapToSelf_NoSwap() throws {
        let test = TestYbridControl(ybridSwr3Endpoint)
        test.playing{ (ybrid) in
             test.swapServiceSynced(to: "swr3-live")
        }

        test.checkErrors(expected: 1)
            .checkAllActions(confirm: 1, withinS: 1.0)
    }
    
    
    func test13_SwapFromAdDemo_NoService() throws {
        
        let test = TestYbridControl(ybridAdDemoEndpoint)
        test.playing{ (ybrid) in
            test.swapServiceSynced(to: "adaptive-demo", maxWait: 6.0)
         }

        test.checkErrors(expected: 1)
            .checkAllActions(confirm: 1, areCompleted:false, withinS: 2.0)
    }
  
    func test14_SwapBackFromSwapped_InTime() throws {
        let test = TestYbridControl(ybridSwr3Endpoint)

        test.playing{ [self] (ybrid) in
            test.swapServiceSynced(to: "swr-raka09", maxWait: 15.0)
            test.swapServiceSynced(to: "swr3-live", maxWait: 15.0)
        }

        test.checkErrors(expected: 0)
            .checkAllActions(confirm: 2, withinS: YbridSwapServiceTests.maxAudioComplete)
    }
  
    func test15_SwapSwapped__fails() throws {
        let test = TestYbridControl(ybridSwr3Endpoint)
        test.playing{ [self] (ybrid) in
            test.swapServiceSynced(to: "swr-raka09", maxWait: 15.0)
            test.swapServiceSynced(to: "swr-raka05", maxWait: 20.0)
        }

        test.checkErrors(expected: 0)
            .checkAllActions(confirm: 2, withinS: YbridSwapServiceTests.maxAudioComplete)
    }
}
