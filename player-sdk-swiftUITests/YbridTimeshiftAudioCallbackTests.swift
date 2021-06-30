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

class YbridTimeshiftAudioCallbackTests: XCTestCase {

    static let maxWindingComplete:TimeInterval = 4.0
    var listener = TimingListener()
    let poller = Poller()
    var actions:[ActionTrace] = []
    override func setUpWithError() throws {
    }
    override func tearDownWithError() throws {
        listener.cleanUp()
        actions.removeAll()
    }

    func test01_WindBackLive_Swr3() throws {
        let windsTook = try playWindByWindToLive(ybridSwr3Endpoint, windBy: -300)
        windsTook.forEach{
            let windTook = $0; let maxWind = YbridTimeshiftAudioCallbackTests.maxWindingComplete
            XCTAssertLessThan(windTook, maxWind, "winding should take less than \(maxWind.S), took \(windTook.S)")
        }
    }
    
    func test02_WindToWindForward_Swr3() throws {
        let windsTook = try playWindToLastFullHourWindForward(ybridSwr3Endpoint, windBy: 30)
        windsTook.forEach{
            let windTook = $0; let maxWind = YbridTimeshiftAudioCallbackTests.maxWindingComplete
            XCTAssertLessThan(windTook, maxWind, "winding should take less than \(maxWind.S), took \(windTook.S)")
        }
    }
    
    func test03_SkipBackNewsSkipMusic_Swr3() throws {
        let windsTook = try playSkipBackNewsSkipForward(ybridSwr3Endpoint)
        windsTook.forEach{
            let windTook = $0; let maxWind = YbridTimeshiftAudioCallbackTests.maxWindingComplete
            XCTAssertLessThan(windTook, maxWind, "winding should take less than \(maxWind.S), took \(windTook.S)")
        }
    }
    
    private func playWindByWindToLive(_ endpoint:MediaEndpoint, windBy:TimeInterval) throws -> [TimeInterval] {
        
         try playingYbridControl(endpoint) { [self] (ybridControl) in
            let actionSemaphore = DispatchSemaphore(value: 0)
            
            var trace1 = ActionTrace(triggered: Date())
            ybridControl.wind(by: windBy) { (changed) in
                trace1.completed = Date()
                trace1.acted = changed
                actions.append(trace1)

                Logger.testing.notice( "***** audio complete ***** \(changed ? "":"not ")winding by \(windBy.S)")
                sleep(3)
                
                var trace2 = ActionTrace()
                trace2.triggered = Date()
                ybridControl.windToLive() { (changed) in
                    trace2.completed = Date()
                    trace2.acted = changed
                    actions.append(trace2)
                    Logger.testing.notice( "***** audio complete ***** \(changed ? "":"not ")winding back to live")
                    sleep(3)

                    actionSemaphore.signal()
                }
            }
            _ = actionSemaphore.wait(timeout: .distantFuture)
        }
        return checkTraces(expectedActions: 2, expectedErrors: 0)
    }

    private func playWindToLastFullHourWindForward(_ endpoint:MediaEndpoint, windBy:TimeInterval) throws -> [TimeInterval] {
 
        try playingYbridControl(endpoint) { [self] (ybridControl) in
            let actionSemaphore = DispatchSemaphore(value: 0)
            
            var trace1 = ActionTrace(triggered: Date())
            let date = lastFullHour(secondsBefore:-4)
            ybridControl.wind(to:date) { (changed) in
                trace1.completed = Date()
                trace1.acted = changed
                actions.append(trace1)

                Logger.testing.notice( "***** audio complete ***** \(changed ? "":"not ")winding to \(date)")
                sleep(3)
                
                var trace2 = ActionTrace()
                trace2.triggered = Date()
                ybridControl.wind(by:windBy) { (changed) in
                    trace2.completed = Date()
                    trace2.acted = changed
                    actions.append(trace2)
                    Logger.testing.notice( "***** audio complete ***** \(changed ? "":"not ")winding forward")
                    sleep(3)
                    actionSemaphore.signal()
                }
            }
            _ = actionSemaphore.wait(timeout: .distantFuture)
        }
        return checkTraces(expectedActions: 2, expectedErrors: 0)
    }
  
    private func playSkipBackNewsSkipForward(_ endpoint:MediaEndpoint) throws -> [TimeInterval] {

        try playingYbridControl(endpoint) { [self] (ybridControl) in
           let actionSemaphore = DispatchSemaphore(value: 0)
           
            var trace1 = ActionTrace(triggered: Date())
            ybridControl.skipBackward(ItemType.NEWS) { (changed) in
                trace1.completed = Date()
                trace1.acted = changed
                actions.append(trace1)

                Logger.testing.notice( "***** audio complete ***** \(changed ? "":"not ")skip to latest NEWS")
                sleep(8)
                
                var trace2 = ActionTrace(triggered:Date())
                ybridControl.skipForward() { (changed) in
                    trace2.completed = Date()
                    trace2.acted = changed
                    self.actions.append(trace2)
                    Logger.testing.notice( "***** audio complete ***** \(changed ? "":"not ")skip item forward")
                    sleep(8)
                    actionSemaphore.signal()
                }
            }
           _ = actionSemaphore.wait(timeout: .distantFuture)
       }
       return checkTraces(expectedActions: 2, expectedErrors: 0)
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
    
    private func lastFullHour(secondsBefore:Int) -> Date {
        let date = Date()
        var components = Calendar.current.dateComponents([.minute, .second], from: date)
        let minute = components.minute ?? 0
        if minute > 0 {
            components.minute = -minute
        }
        let seconds = components.second ?? 0
        if seconds > 0 {
            components.second = -seconds - secondsBefore
        }
        return Calendar.current.date(byAdding: components, to: date)!
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
