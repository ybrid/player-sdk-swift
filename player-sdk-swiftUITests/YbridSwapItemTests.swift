//
// YbridSwapItemTests.swift
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

class YbridSwapItemTests: XCTestCase {

    static let maxAudioComplete:TimeInterval = 4.0
    var listener = TestYbridPlayerListener()
    var testControl:TestYbridControl?
    let poller = Poller()
    override func setUpWithError() throws {
        testControl = TestYbridControl(ybridDemoEndpoint, listener: listener)
    }
    override func tearDownWithError() throws {
        listener.reset()
    }
    
    func test01_stopped_SwapsLeft_0() throws {
        
        guard let test = testControl else {
            XCTFail("cannot use ybrid test control."); return
        }
        
        test.stopped() { (ybridControl) in
            usleep(10_000)
        }
        
        XCTAssertEqual(test.listener.swapsLeft, 0, "\(String(describing: test.listener.swapsLeft)) swaps are left.")
        
        let titles:[String] =
            test.listener.metadatas.map{ $0.displayTitle ?? "(nil)"}
        Logger.testing.info( "titles were \(titles)")
    }

    
    func test02_playing_SwapsLeft_SwapSwap() throws {
        guard let test = testControl else {
            XCTFail("cannot use ybrid test control."); return
        }
        
        test.playing() { [self] (ybridControl) in
            
            guard let swaps = test.listener.swapsLeft, swaps != 0 else {
                XCTFail("currently no swaps left. Execute test later"); return
            }
            Logger.testing.info("\(swaps) swaps are left")
            
            guard let titleMain = test.listener.metadatas.last?.displayTitle else {
                XCTFail("must have recieved metadata"); return
            }
            Logger.testing.info("title main =\(titleMain)")
            
            var titleSwapped:String?
            ybridControl.swapItem()
            _ = poller.wait(max: 10) {
                guard let swapped = test.listener.metadatas.last?.displayTitle else {
                    return false
                }
                titleSwapped = swapped
                Logger.testing.info("title swapped =\(titleSwapped!)")
                return titleMain != titleSwapped!
            }
            sleep(2)
            
            ybridControl.swapItem()
            _ = poller.wait(max: 10) {
                guard let titleSwapped2 = test.listener.metadatas.last?.displayTitle else {
                    return false
                }
                Logger.testing.info("title swapped =\(titleSwapped2)")
                return titleSwapped2 != titleSwapped
            }
            sleep(2)
        }
        
        let titles:[String] =
            test.listener.metadatas.map{ $0.displayTitle ?? "(nil)"}
        Logger.testing.info( "titles were \(titles)")
        
        XCTAssertTrue((3...5).contains(test.listener.metadatas.count), "should be 3 (5 if item changed) metadata changes, but were \(test.listener.metadatas.count)")
    }
    
    func test03_SwapItem_AudioCompleteCalled() throws {
        guard let test = testControl else {
            XCTFail("cannot use ybrid test control."); return
        }
        
        test.playing() { [self] (ybridControl) in
            guard let swaps = test.listener.swapsLeft, swaps != 0 else {
                XCTFail("currently no swaps left. Execute test later")
                return
            }
            Logger.testing.info("\(swaps) swaps are left")
            
            var carriedOut = false
            ybridControl.swapItem { (success) in
                carriedOut = success
            }
            _ = poller.wait(max: 10) {
                carriedOut == true
            }
            XCTAssertTrue(carriedOut, "swap was not carried out")
        }
        
        let titles:[String] = test.listener.metadatas.map{ $0.displayTitle ?? "(nil)"}
        Logger.testing.info( "titles were \(titles)")
        
        let differentTitles = Set(titles)
        Logger.testing.info( "different titles were \(differentTitles)")
        XCTAssertEqual(differentTitles.count, 2)
        
        XCTAssertTrue((2...3).contains(test.listener.metadatas.count), "should be 2 (3 if item changed) metadata changes, but were \(listener.metadatas.count)")
    }

    // MARK: using audio complete
    
    func test11_SwapItem_complete() throws {
        let testControl = TestYbridControl(ybridDemoEndpoint, listener: listener)
        testControl.playing{ (_) in
            testControl.swapItemSynced(maxWait: 8.0)
        }
        testControl.checkErrors(expected: 0)
        .checkAllActions(confirm: 1, withinS: YbridSwapItemTests.maxAudioComplete)
    }
    
    func test12_SwapItem_3Times() throws {
        let testControl = TestYbridControl(ybridDemoEndpoint, listener: listener)
        testControl.playing{ (_) in
            testControl.swapItemSynced(maxWait: 8.0)
            testControl.swapItemSynced(maxWait: 8.0)
            testControl.swapItemSynced(maxWait: 8.0)
        }
        testControl.checkErrors(expected: 0)
            .checkAllActions(confirm: 3, withinS: YbridSwapItemTests.maxAudioComplete)
    }
    
    func test13_SwapItemFromAd_doesntSwap() throws {
        let testControl = TestYbridControl(ybridAdDemoEndpoint, listener: listener)
        
        testControl.playing{ (ybrid) in
            testControl.swapItemSynced(maxWait: 8.0)
        }
        
        testControl.checkErrors(expected: 1)
            .checkAllActions(confirm: 1, withinS: 1.0)
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

