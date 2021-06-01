//
// SteelinessTests.swift
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

class YbridSteelinessTests: XCTestCase {
    
    let listener = MediaListener()
    func testSteelinessStage_InfoResponse_WithoutMillisHappen() throws {
        guard let player = AudioPlayer.openSync(for: ybridStageDemoEndpoint, listener: listener) else {
            XCTFail("player expected"); return
        }
        for i in 1...5000 {
            if i % 25 == 0 {
                print("session info \(i)")
            }
            player.session.refresh()
        }
        
        player.close()
    }
  
   
    func testSteelinessProd_InfoResponse_WithoutMillisHappen() throws {
        guard let player = AudioPlayer.openSync(for: ybridSwr3Endpoint.forceProtocol(.ybridV2), listener: listener) else {
            XCTFail("player expected"); return
        }
        for i in 1...5000 {
            player.session.refresh()
            if i % 25 == 0 {
                print("session info \(i)")
            }
        }
        
        player.close()
    }
  
    func testSteelinessSession_OptionsCreateClose() throws {
        for i in 1...1000 {
          
            guard let player = AudioPlayer.openSync(for: ybridStageDemoEndpoint, listener: listener) else {
                XCTFail("player expected");
                continue
            }
            if i % 25 == 0 {
                print("options create close session \(i)")
            }
            player.close()
        }
    }

    func testSteelinessSession_CreateClose() throws {
        for i in 1...1000 {
          
            guard let player = AudioPlayer.openSync(for: ybridStageDemoEndpoint.forceProtocol(.ybridV2), listener: listener) else {
                XCTFail("player expected");
                continue
            }
            if i % 25 == 0 {
                print("options create close session \(i)")
            }
            player.close()
        }
    }
   
    class MediaListener : ControlListener {
        func stateChanged(_ state: PlaybackState) {}
        func metadataChanged(_ metadata: Metadata) {}
        func playingSince(_ seconds: TimeInterval?) {}
        func durationReadyToPlay(_ seconds: TimeInterval?) {}
        func durationConnected(_ seconds: TimeInterval?) {}
        func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {}
        
        var errors:[AudioPlayerError] = []
        func error(_ severity: ErrorSeverity, _ exception: AudioPlayerError) {
            errors.append(exception)
        }
    }
}
