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

    let swr3MinServicesCount = 5
    
    let maxControlComplete:TimeInterval = 0.21
    let maxAudioChanged:TimeInterval = 1.008
    
    let poller = Poller()
    
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
        XCTAssertGreaterThan(test.listener.services[0].count, swr3MinServicesCount)
        
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
        
        XCTAssertEqual(test.listener.services.count, 2) // one initially, one because of swap
        guard test.listener.services.count > 0 else {
            XCTFail("no changed swaps"); return
        }
        XCTAssertGreaterThan(test.listener.services[0].count, swr3MinServicesCount)

        
        let services:[String] =
            test.listener.metadatas.map{ $0.service.identifier }
        Logger.testing.info("services were \(services)")
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
            poller.wait(ybridControl, until: PlaybackState.playing, maxSeconds: 5)
            
            let buffer = test.listener.bufferDuration ?? 0
            let maxWait = Int(buffer + maxAudioChanged)+1
            Logger.testing.debug("buffer \(buffer.S), max wait \(maxWait) s")
            _ = poller.wait(max: maxWait) {
                let serviceSwapped = test.listener.metadatas.last?.service
                Logger.testing.info("service=\(String(describing: serviceSwapped))")
                return serviceSwapped?.identifier == "swr-raka09"
            }
        }

        _ = test.checkErrors(expected: 0)
        
        let servicesCalls = test.listener.services.count
        guard servicesCalls > 0 else {
            XCTFail(); return
        }
        XCTAssertGreaterThan(test.listener.services[0].count, swr3MinServicesCount)
        
        let services:[String] =
            test.listener.metadatas.map{ $0.service.identifier }
        Logger.testing.info("services were \(services)")
        
        XCTAssertGreaterThanOrEqual(test.listener.metadatas.count, 1)
        XCTAssertEqual("swr3-live",  test.listener.metadatas.first?.service.identifier)
        XCTAssertEqual("swr3-live",  test.listener.metadatas.last?.service.identifier)
    }
    
    func test04_OnPlay_ActiveServiceInNextMetadata() throws {
        let test = TestYbridControl(ybridSwr3Endpoint)
        test.playing{ [self] (ybridControl) in
            usleep(200_000)
            let buffer = test.listener.bufferS
            let maxWait: Int = buffer + Int(maxAudioChanged)+1
            
            let mainService = test.listener.metadatas.last?.service
            ybridControl.swapService(to:"swr-raka09")
            _ = poller.wait(max: maxWait) {
                let serviceSwapped = test.listener.metadatas.last?.service
                Logger.testing.info("service=\(String(describing: serviceSwapped))")
                return serviceSwapped?.identifier != mainService?.identifier
            }
            
            ybridControl.stop()
            poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 1)
        }

        _ = test.checkErrors(expected: 0)
        
        let services:[String] =
            test.listener.metadatas.map{ $0.service.identifier }
        Logger.testing.info( "services were \(services)")
        
        XCTAssertGreaterThanOrEqual(services.count, 2, "should be 2 different active services, but were \(services.count)")
    }
    
    func test05_AfterStop_TakesEffekt() throws {
        let test = TestYbridControl(ybridSwr3Endpoint)
        XCTAssertEqual(test.listener.services.count, 0)
        test.playing{ [self] (ybridControl) in
            
            ybridControl.stop()
            poller.wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)            
            XCTAssertEqual(test.listener.services.count, 1)
            
            var carriedOut = false
            ybridControl.swapService(to: "swr-raka09") { (success) in
                carriedOut = success
            }
            _ = poller.wait(max: 1) {
                carriedOut == true
            }
            XCTAssertTrue(carriedOut, "swap was not carried out")
            
            ybridControl.play()
            usleep(200_000)
            let buffer = test.listener.bufferS
            let maxWait: Int = buffer + Int(maxAudioChanged)+1
            
            _ = poller.wait(max: maxWait) {
                let serviceSwapped = test.listener.metadatas.last?.service
                Logger.testing.info("service=\(String(describing: serviceSwapped))")
                return serviceSwapped?.identifier == "swr-raka09"
            }
        }

        _ = test.checkErrors(expected: 0)
        
        XCTAssertEqual(test.listener.services.count, 2) // one initially, one because of swap
        test.listener.services.forEach{
            XCTAssertGreaterThan($0.count, swr3MinServicesCount)
        }
        
        
        let services:[String] =
            test.listener.metadatas.map{ $0.service.identifier }
        Logger.testing.info( "services were \(services)")
        
        XCTAssertEqual("swr3-live",  test.listener.metadatas.first?.service.identifier)
        XCTAssertEqual("swr-raka09",  test.listener.metadatas.last?.service.identifier)
    }
    
    // MARK: using audio complete
    
   
    func test11_Play_SwapComplete_ok() throws {
        let test = TestYbridControl(ybridSwr3Endpoint)
        var buffer = 0.0
        test.playing{ (ybrid) in
            usleep(200_000)
            buffer += test.listener.bufferDuration ?? 0
            test.swapServiceSynced(to: "swr-raka06")
        }
        
        test.checkErrors(expected: 0)
            .checkAllActions(confirm: 1, withinS: buffer + maxAudioChanged)
    }
    
    func test12_SwapToSelf_NoSwap() throws {
        let test = TestYbridControl(ybridSwr3Endpoint)
        test.playing{ (ybrid) in
             test.swapServiceSynced(to: "swr3-live")
        }

        test.checkErrors(expected: 1)
            .checkAllActions(confirm: 1, withinS: maxControlComplete)
    }
    
    func test13_SwapFromAdDemo_NoService() throws {

        let test = TestYbridControl(ybridAdDemoEndpoint)
        test.playing{ (ybrid) in
            test.swapServiceSynced(to: "adaptive-demo", maxWait: self.maxAudioChanged)
         }

        test.checkErrors(expected: 1)
            .checkAllActions(confirm: 1, areCompleted:false, withinS: maxControlComplete)
    }
  
    func test14_SwapBackFromSwapped_InTime() throws {
        let test = TestYbridControl(ybridSwr3Endpoint)
        var maxAudioComplete = maxAudioChanged
        test.playing{ (ybrid) in
            usleep(200_000)
            maxAudioComplete += test.listener.bufferDuration ?? 0
            test.swapServiceSynced(to: "swr-raka09", maxWait: maxAudioComplete)
            test.swapServiceSynced(to: "swr3-live", maxWait: maxAudioComplete)
        }

        test.checkErrors(expected: 0)
            .checkAllActions(confirm: 2, withinS: maxAudioComplete)
    }
  
    func test15_SwapSwapped__fails() throws {
        let test = TestYbridControl(ybridSwr3Endpoint)
        test.listener.logBufferSize = false
        test.listener.logPlayingSince = false
        var maxAudioComplete = maxAudioChanged
        test.playing{ (ybrid) in
            usleep(200_000)
            maxAudioComplete += test.listener.bufferDuration ?? 0
            test.swapServiceSynced(to: "swr-raka09", maxWait: maxAudioComplete)
            test.swapServiceSynced(to: "swr-raka05", maxWait: maxAudioComplete) // icy trigger is too late --> maxAudioComplete + 10 succeeds
        }

        test.checkErrors(expected: 0)
            .checkAllActions(confirm: 2, withinS: maxAudioComplete)  // + 10 succeeds
    }
}
