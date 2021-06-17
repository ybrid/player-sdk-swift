//
// PlaybackOrYbridContolTests.swift
// player-sdk-swiftUITests
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

class ContolMatchesProtocolTests: XCTestCase {

    var semaphore:DispatchSemaphore?
    override func setUpWithError() throws {
        semaphore = DispatchSemaphore(value: 0)
    }
    override func tearDownWithError() throws {
        _ = semaphore?.wait(timeout: .distantFuture)
    }
    
    func test01_Ybrid_Play3Seconds() throws {
        
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: nil,
         playbackControl: { (control) in
            XCTFail("this should not be called. Protocol is not \(MediaProtocol.icy)")
            self.semaphore?.signal()
         },
         ybridControl: { [self] (ybridControl) in
            
            XCTAssertEqual(.ybridV2, ybridControl.mediaProtocol)
            
            let offset = ybridControl.offsetToLiveS
            Logger.testing.notice("offset to live is \(offset.S)")
            XCTAssertLessThanOrEqual(offset, 0.0)
            XCTAssertGreaterThan(offset, -10.0)
            
            ybridControl.play()
            wait(ybridControl, until: .playing, maxSeconds: 10)
            sleep(3)
            ybridControl.stop()
            wait(ybridControl, until: .stopped, maxSeconds: 2)
            
            semaphore?.signal()
         })
        
    }

    func test02_Icy_Play3Seconds() throws {

        try AudioPlayer.open(for: icecastHr2Endpoint, listener: nil,
            playbackControl: { [self] (playback) in
            
                XCTAssertEqual(MediaProtocol.icy, playback.mediaProtocol)
                
                playback.play()
                wait(playback, until: .playing, maxSeconds: 10)
                sleep(3)
                playback.stop()
                wait(playback, until: .stopped, maxSeconds: 2)
                
                semaphore?.signal()
            },
            ybridControl: { (ybridControl) in
                XCTFail("this should not be called. Protocol is not \(MediaProtocol.ybridV2)")
                self.semaphore?.signal()
            })
    }

    // MARK: helper function
    private func wait(_ ybrid:YbridControl, until:PlaybackState, maxSeconds:Int) {
        wait(ybrid as PlaybackControl, until: until, maxSeconds: maxSeconds)
    }
    private func wait(_ playback:PlaybackControl, until:PlaybackState, maxSeconds:Int) {

        var seconds = 0
        while playback.state != until && seconds <= maxSeconds {
            sleep(1)
            seconds += 1
        }
        print("took \(seconds) second\(seconds > 1 ? "s" : "") until \(playback.state)")
        XCTAssertEqual(until, playback.state)
    }

}
