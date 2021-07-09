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
    let poller = Poller()
    var semaphore:DispatchSemaphore?
    override func setUpWithError() throws {
        semaphore = DispatchSemaphore(value: 0)
    }
    override func tearDownWithError() throws {
        listener.reset()
    }
    
    func test01_stopped_SwapsLeft_0() throws {
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: listener,
                playbackControl: { [self] (control) in
                    XCTFail("ybridControl expected");semaphore?.signal()
                },
                ybridControl: { [self] (ybridControl) in

                XCTAssertEqual(listener.swapsLeft, 0, "\(String(describing: listener.swapsLeft)) swaps are left.")
                    
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        let titles:[String] =
            listener.metadatas.map{ $0.displayTitle ?? "(nil)"}
        Logger.testing.info( "titles were \(titles)")
    }

    
    func test02_playing_SwapsLeft_SwapSwap() throws {
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: listener,
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
                sleep(2)
                    
                guard let swaps = listener.swapsLeft, swaps != 0 else {
                    XCTFail("currently no swaps left. Execute test later"); return
                }
                Logger.testing.info("\(swaps) swaps are left")
                    
                guard let titleMain = listener.metadatas.last?.displayTitle else {
                    XCTFail("must have recieved metadata"); return
                }
                Logger.testing.info("title main =\(titleMain)")
                
                var titleSwapped:String?
                ybridControl.swapItem()
                _ = poller.wait(max: 10) {
                    guard let swapped = listener.metadatas.last?.displayTitle else {
                        return false
                    }
                    titleSwapped = swapped
                    Logger.testing.info("title swapped =\(titleSwapped!)")
                    return titleMain != titleSwapped!
                }
                sleep(2)
                    
                ybridControl.swapItem()
                _ = poller.wait(max: 10) {
                    guard let titleSwapped2 = listener.metadatas.last?.displayTitle else {
                        return false
                    }
                    Logger.testing.info("title swapped =\(titleSwapped2)")
                    return titleSwapped2 != titleSwapped
                }
                sleep(2)

               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        let titles:[String] =
            listener.metadatas.map{ $0.displayTitle ?? "(nil)"}
        Logger.testing.info( "titles were \(titles)")
        
        XCTAssertTrue((3...5).contains(listener.metadatas.count), "should be 3 (5 if item changed) metadata changes, but were \(listener.metadatas.count)")
    }
    
    func test03_SwapItem_AudioCompleteCalled() throws {
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: listener,
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
                    poller.wait(ybridControl, until: PlaybackState.playing, maxSeconds: Int(YbridSwapItemTests.maxAudioComplete))
                    
                    guard let swaps = listener.swapsLeft, swaps != 0 else {
                        XCTFail("currently no swaps left. Execute test later")
                        return
                    }
                    Logger.testing.info("\(swaps) swaps are left")
                    
                    var carriedOut = false
                    ybridControl.swapItem { (audioChanged) in
                        carriedOut = audioChanged
                    }
                    _ = poller.wait(max: 10) {
                        carriedOut == true
                    }
                    XCTAssertTrue(carriedOut, "swap was not carried out")
                }
        )
        _ = semaphore?.wait(timeout: .distantFuture)
//        sleep(1)
        
        let titles:[String] = listener.metadatas.map{ $0.displayTitle ?? "(nil)"}
        Logger.testing.info( "titles were \(titles)")
        
        let differentTitles = Set(titles)
        Logger.testing.info( "different titles were \(differentTitles)")
        XCTAssertEqual(differentTitles.count, 2)
        
        XCTAssertTrue((2...3).contains(listener.metadatas.count), "should be 2 (3 if item changed) metadata changes, but were \(listener.metadatas.count)")
    }

    // MARK: using audio complete
    
    func test11_SwapItemComplete_Demo() throws {
        
        let actionTraces = ActionsTrace()
        TestYbridControl(ybridDemoEndpoint, listener: listener).playing{ [self] (ybrid) in
            actionTraces.append( swapItem(ybrid) )
        }
        
        checkErrors(expectedErrors: 0)
        actionTraces.check(expectedActions: 1, maxDuration: YbridSwapItemTests.maxAudioComplete)
    }
    
    func test12_SwapItemComplete_AdDemo() throws {
        
        let actionTraces = ActionsTrace()
        TestYbridControl(ybridAdDemoEndpoint, listener: listener).playing{ [self] (ybrid) in
            actionTraces.append( swapItem(ybrid) )
        }
        
        checkErrors(expectedErrors: 1)
        actionTraces.check(expectedActions: 1, maxDuration: 1.0)
    }
  
    func swapItem( _ ybrid:YbridControl, maxWait:TimeInterval? = nil) -> (Trace) {
        let mySema = DispatchSemaphore(value: 0)
        let trace = Trace("swap item")
        ybrid.swapItem() { (changed) in
            self.actionComplete(changed, trace)
            mySema.signal()
        }
        if let maxWait = maxWait {
            _ = mySema.wait(timeout: .now() + maxWait)
        } else {
            _ = mySema.wait(timeout: .distantFuture)
        }
        return trace
    }
    
    private func actionComplete(_ changed:Bool,_ trace:Trace) {
       trace.complete(changed)
       Logger.testing.notice( "***** audio complete ***** did \(changed ? "":"not ")\(trace.name)")
       sleep(3)
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
