//
// YbridWindsTimingTests.swift
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
import YbridPlayerSDK

class YbridWindsTimingTests: XCTestCase {

    var listener = TimingListener()
    override func setUpWithError() throws {
    }
    override func tearDownWithError() throws {
        listener.cleanUp()
    }

    func test11_WindBackLive_Swr3() throws {
        let windsTook = try playWindByWindToLive(ybridSwr3Endpoint, windBy: -300)
        windsTook.forEach{
            let windTook = $0
            XCTAssertLessThan(windTook, 4, "winding should take less than 4s, took \(windTook.S)")
        }
    }
    
    private func playWindByWindToLive(_ endpoint:MediaEndpoint, windBy:TimeInterval) throws -> [TimeInterval] {
        let semaphore = DispatchSemaphore(value: 0)
        let listener = TimingListener()
        var actionsTriggered:[Date] = []
        var actionsCompleted:[Date] = []
        
        try AudioPlayer.open(for: endpoint, listener: listener,
             playbackControl: { (ctrl) in semaphore.signal()
                XCTFail(); return },
             ybridControl: { (ybridControl) in

                ybridControl.play()
                player_sdk_swiftTests.wait(ybridControl, until:PlaybackState.playing, maxSeconds:10)
              
                actionsTriggered.append(Date())
                ybridControl.wind(by: windBy) { (changed) in
                    actionsCompleted.append(Date())

                    Logger.testing.notice( "***** audio complete ***** \(changed ? "":"not ")winding by \(windBy.S)")
                    sleep(4)
                    
                    actionsTriggered.append(Date())
                    ybridControl.windToLive() { (changed) in
                        actionsCompleted.append(Date())

                        XCTAssertTrue(changed, "should have winded back to live.")
                        Logger.testing.notice( "***** audio complete ***** \(changed ? "":"not ")winding back to live")
                        sleep(2)
                        
                        ybridControl.stop()
                        sleep(1)
                        ybridControl.close()
                        semaphore.signal()
                    }
                    
                }
            }
        )
        _ = semaphore.wait(timeout: .distantFuture)
        let errCount = listener.errors.count
        guard errCount == 0 else {
            let err =  listener.errors[0]
            let errMessage = err.localizedDescription
            XCTFail(errMessage)
            throw SessionError(ErrorKind.unknown, errMessage)
        }
        
        var actionsTook:[TimeInterval] = []
        guard actionsTriggered.count == 2 else {
            XCTFail()
            return actionsTook
        }
        
        for i in 0...actionsTriggered.count-1 {
            let actionStarted = actionsTriggered[i]
            let actionEnded = actionsCompleted[i]
            let actionTookS = actionEnded.timeIntervalSince(actionStarted)
            Logger.testing.debug("winding took \(actionTookS.S)")
            actionsTook.append(actionTookS)
        }
        return actionsTook
    }

}
