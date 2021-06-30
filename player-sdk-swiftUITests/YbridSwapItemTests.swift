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
    var actions:[ActionTrace] = []
    var semaphore:DispatchSemaphore?
    override func setUpWithError() throws {
        semaphore = DispatchSemaphore(value: 0)
    }
    override func tearDownWithError() throws {
        listener.reset()
    }
    
    func test01_SwapsLeft_WithoutPlaying_0() throws {
        Logger.verbose = true
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: listener,
                playbackControl: { [self] (control) in
                    XCTFail("ybridControl expected");semaphore?.signal()
                },
                ybridControl: { [self] (ybridControl) in
                    sleep(1) // the listener is notified asynchronously
                    XCTAssertEqual(0, listener.swapsLeft, "\(String(describing: listener.swapsLeft)) swaps are left.")
                    
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        let titles:[String] =
            listener.metadatas.map{ $0.displayTitle ?? "(nil)"}
        Logger.testing.info( "titles were \(titles)")
    }

    
    func test02_SwapItem_WhilePlaying() throws {
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
                
                ybridControl.swapItem()
                _ = poller.wait(max: 10) {
                    guard let titleSwapped2 = listener.metadatas.last?.displayTitle else {
                        return false
                    }
                    Logger.testing.info("title swapped =\(titleSwapped2)")
                    return titleSwapped2 != titleSwapped
                }

               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        let titles:[String] =
            listener.metadatas.map{ $0.displayTitle ?? "(nil)"}
        Logger.testing.info( "titles were \(titles)")
        
        XCTAssertTrue((3...4).contains(listener.metadatas.count), "should be 3 (4 if item changed) metadata changes, but were \(listener.metadatas.count)")
    }
    
    func test03_SwapItem_AudioCompleteCallbackIsCalled() throws {
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
                sleep(2)
                    
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        let titles:[String] =
        listener.metadatas.map{ $0.displayTitle ?? "(nil)"}
        Logger.testing.info( "titles were \(titles)")
        
        let differentTitles = Set(titles)
        Logger.testing.info( "different titles were \(differentTitles)")
        XCTAssertEqual(2, differentTitles.count)
        
        XCTAssertTrue((2...3).contains(listener.metadatas.count), "should be 2 (3 if item changed) metadata changes, but were \(listener.metadatas.count)")
    }

    func test05_SwapItemComplete_Demo() throws {
        try playAndSwapItem(ybridDemoEndpoint)
        let swapsTook = checkTraces(expectedActions: 1, expectedErrors: 0)
        swapsTook.forEach{
            let swapTook = $0; let maxSwap = YbridSwapItemTests.maxAudioComplete
            XCTAssertLessThan(swapTook, maxSwap, "swapping item should take less than \(maxSwap.S), took \(swapTook.S)")
        }
    }
   
    func test06_SwapItemComplete_AdDemo() throws {
        try playAndSwapItem(ybridAdDemoEndpoint)
        let swapsTook = checkTraces(expectedActions: 1, expectedErrors: 1)
        swapsTook.forEach{
            let swapTook = $0; let maxNotSwap = 1.0
            XCTAssertLessThan(swapTook, maxNotSwap, "swapping item should take less than \(maxNotSwap.S), took \(swapTook.S)")
        }
    }
    
    private func playAndSwapItem(_ endpoint:MediaEndpoint) throws {
        
        try playingYbridControl(endpoint) { [self] (ybridControl) in
            let actionSemaphore = DispatchSemaphore(value: 0)
            
            var trace1 = ActionTrace(triggered: Date())
            ybridControl.swapItem() { (changed) in
                trace1.completed = Date()
                trace1.acted = changed
                actions.append(trace1)
                Logger.testing.info( "***** audio complete ***** \(changed ? "":"not ")swapping item")
                sleep(3)
                
                actionSemaphore.signal()
            }
            _ = actionSemaphore.wait(timeout: .distantFuture)
        }
    }
    
    
    // generic Control playing, executing actionSync and stopping control
    private func playingYbridControl(_ endpoint:MediaEndpoint, actionSync: @escaping (YbridControl)->() ) throws {
        let playingSmaphore = DispatchSemaphore(value: 0)

        try AudioPlayer.open(for: endpoint, listener: listener,
             playbackControl: { (ctrl) in playingSmaphore.signal()
                XCTFail(); return },
             ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                poller.wait(ybridControl, until:PlaybackState.playing, maxSeconds:10)
                
                actionSync(ybridControl)
                
                ybridControl.stop()
                sleep(2)
                ybridControl.close()
                playingSmaphore.signal()
             })
        _ = playingSmaphore.wait(timeout: .distantFuture)
    }
    
    struct ActionTrace {
        var triggered:Date? = nil
        var completed:Date? = nil
        var acted:Bool = false
    }
    
    private func checkTraces(expectedActions:Int, expectedErrors:Int) -> [TimeInterval] {
        guard listener.errors.count == expectedErrors else {
            XCTFail("\(expectedErrors) errors expected, but were \(listener.errors.count)")
            if let err =  listener.errors.first {
                let errMessage = err.localizedDescription
                XCTFail("first error is \(errMessage)")
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
