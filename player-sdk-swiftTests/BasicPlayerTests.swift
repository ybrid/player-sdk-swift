//
// BasicPlayerTests.swift
// player-sdk-swiftTests
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

class BasicPlayerTests: XCTestCase {

    var semaphore:DispatchSemaphore?
    let poller = Poller()
    let maxWait = 5
    override func setUpWithError() throws {
        Logger.verbose = true
        semaphore = DispatchSemaphore(value: 0)
    }
    override func tearDownWithError() throws {
        _ = semaphore?.wait(timeout: .distantFuture)
    }
 

    func testPlayMp3_400ms() throws {
        let shortEndpoint = MediaEndpoint(mediaUri: "https://github.com/ybrid/test-files/blob/main/mpeg-audio/sounds/test400ms.mp3?raw=true")
        try AudioPlayer.open(for: shortEndpoint, listener: nil) { [self] (control) in
            
            control.play()
            poller.wait(control, untilState: .playing, intervalMs: 50, maxS: maxWait)

            poller.wait(control, untilState: .stopped, maxS: 2)
            semaphore?.signal()
        }
    }

    func testPlayMp3_100ms() throws {
        let shortEndpoint = MediaEndpoint(mediaUri: "https://github.com/ybrid/test-files/blob/main/mpeg-audio/sounds/test100ms.mp3?raw=true")
        try AudioPlayer.open(for: shortEndpoint, listener: nil) { [self] (control) in
            
            control.play()
            poller.wait(control, untilState: .playing, intervalMs: 10, maxS: maxWait)

            poller.wait(control, untilState: .stopped, maxS: 2)
            semaphore?.signal()
        }
    }
    
    func testPlayMp3_10ms() throws {
        let shortEndpoint = MediaEndpoint(mediaUri: "https://github.com/ybrid/test-files/blob/main/mpeg-audio/sounds/test10ms.mp3?raw=true")
        try AudioPlayer.open(for: shortEndpoint, listener: nil) { [self] (control) in
            
            control.play()
            poller.wait(control, untilState: .playing, intervalMs: 5, maxS: maxWait)

            poller.wait(control, untilState: .stopped, maxS: 2)
            semaphore?.signal()
        }
    }
    
    func testPlayFlac_400ms() throws {
        let shortEndpoint = MediaEndpoint(mediaUri: "https://github.com/ybrid/test-files/blob/main/flac/test400ms.flac?raw=true")
        try AudioPlayer.open(for: shortEndpoint, listener: nil) { [self] (control) in
            
            control.play()
            poller.wait(control, untilState: .playing, intervalMs: 100, maxS: maxWait)

            poller.wait(control, untilState: .stopped, maxS: 2)
            semaphore?.signal()
        }
    }
    
}
