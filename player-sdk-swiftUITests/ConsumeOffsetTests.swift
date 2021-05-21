//
// ConsumeOffsetTests.swift
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

class ConsumeOffsetTests: XCTestCase {

    var player:YbridControl?
    let allListener = TestYbridPlayerListener()
    var semaphore:DispatchSemaphore?
    override func setUpWithError() throws {
        // Log additional debug information in this tests
        Logger.verbose = true
        allListener.reset()
        semaphore = DispatchSemaphore(value: 0)
    }
    
    override func tearDownWithError() throws {}
    
    func test01_YbridCanGet_ButNoListener() throws {
        
        try AudioPlayer.initialize(for: ybridStageSwr3Endpoint, listener: allListener,
               ybridControl: { [self] (ybridControl) in
                
                let offset = ybridControl.offsetToLiveS
                Logger.testing.notice("offset to live is \(offset.S)")
                XCTAssertLessThan(offset, -0.5)
                XCTAssertGreaterThan(offset, -5.0)
                
                ybridControl.play()
                _ = wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(1)
                ybridControl.stop()
                _ = wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertEqual(0, allListener.offsetChanges)
    }
    
    func test02_YbridControl_WithListener() throws {
        
        try AudioPlayer.initialize(for: ybridStageSwr3Endpoint, listener: nil,
               ybridControl: { [self] (ybridControl) in
                var control = ybridControl
                
                allListener.control = ybridControl
                control.listener = allListener
                
                ybridControl.play()
                _ = wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(1)
                ybridControl.stop()
                _ = wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertEqual(1, allListener.offsetChanges)
    }
    

    private func wait(_ control:YbridControl, until:PlaybackState, maxSeconds:Int) -> Int {
        var seconds = 0
        while control.state != until && seconds < maxSeconds {
            sleep(1)
            seconds += 1
        }
        XCTAssertEqual(until, control.state, "not \(until) within \(maxSeconds) s")
        return seconds
    }
    
}

class TestYbridPlayerListener : TestAudioPlayerListener, YbridControlListener {
    
    var control:YbridControl?
    
    var offsetChanges = 0
    func offsetToLiveChanged() {
        offsetChanges += 1
        
        guard let offset = control?.offsetToLiveS else { XCTFail(); return }
        Logger.testing.notice("offset to live is \(offset.S)")
        XCTAssertLessThan(offset, -0.5)
        XCTAssertGreaterThan(offset, -5.0)
        
    }
    
    override func reset() {
        super.reset()
        offsetChanges = 0
    }
}
