//
// YbridControlTests.swift
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

class YbridTimeshiftTests: XCTestCase {

    static let maxWindComplete = 4.0
    let maxWindResponseS = 2
    let liveOffsetRange_LostSign = TimeInterval(0.0) ..< TimeInterval(10.0)

    let ybridPlayerListener = TestYbridPlayerListener()
    var semaphore:DispatchSemaphore?
    
    override func setUpWithError() throws {
        // don't log additional debug information in this tests
        Logger.verbose = false
        ybridPlayerListener.reset()
        semaphore = DispatchSemaphore(value: 0)
    }
    
    override func tearDownWithError() throws {
        print( "offsets were \(ybridPlayerListener.offsets)")
    }
    
    func test01_InitialOffsetChange() throws {

        try AudioPlayer.open(for: ybridSwr3Endpoint, listener: ybridPlayerListener,
               playbackControl: failOnPlaybackControl,
               ybridControl: { [self] (ybridControl) in

                usleep(20_000)

                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)

        XCTAssertEqual(ybridPlayerListener.offsets.count, 1)
    }
    
    private func failOnPlaybackControl(_ control:PlaybackControl) {
        XCTFail("YbridControl expected, but was PlaybackControl")
        semaphore?.signal()
    }
    
    func test02_PlayOffsetChanges() throws {
        
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: ybridPlayerListener,
               playbackControl: failOnPlaybackControl,
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertGreaterThanOrEqual(ybridPlayerListener.offsets.count, 1)
        ybridPlayerListener.offsets.forEach{
            XCTAssertTrue(liveOffsetRange_LostSign.contains(-$0))
        }
    }
    
    func test03_WindBackward120_WindForward60() throws {
        try AudioPlayer.open(for: ybridSwr3Endpoint, listener: ybridPlayerListener,
             playbackControl: failOnPlaybackControl,
             ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
        
                ybridControl.wind(by: -120.0)
                wait(ybridPlayerListener, shifted: -120.0, maxSeconds: maxWindResponseS)
                sleep(4)
                
                ybridControl.wind(by: 60.0)
                wait(ybridPlayerListener, shifted: -60.0, maxSeconds: maxWindResponseS)
                sleep(4)
                
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertGreaterThanOrEqual(ybridPlayerListener.offsets.count, 2, "expected to be at least the initial and one more change of offset")
        guard let lastOffset = ybridPlayerListener.offsets.last else {
            XCTFail(); return
        }
        let shiftedRangeNegated = shift(liveOffsetRange_LostSign, by: +60.0)
        XCTAssertTrue(shiftedRangeNegated.contains(-lastOffset), "\(-lastOffset) not within \(shiftedRangeNegated)")
    }
    
    
    func test04_Wind_Cannot() throws {
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: ybridPlayerListener,
             playbackControl: failOnPlaybackControl,
             ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
        
                ybridControl.wind(by: -120.0)
                sleep(4)
                
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertGreaterThanOrEqual(ybridPlayerListener.offsets.count, 1, "expected to be only the initial change of offset")
        guard let lastOffset = ybridPlayerListener.offsets.last else {
            XCTFail(); return
        }
        let shiftedRangeNegated = shift(liveOffsetRange_LostSign, by: 0.0)
        XCTAssertTrue(shiftedRangeNegated.contains(-lastOffset), "\(-lastOffset) not within \(shiftedRangeNegated)")
        
        guard let error = ybridPlayerListener.errors.last else {
            XCTFail( "expected an error message"); return
        }
        XCTAssertTrue(error.message?.contains("cannot wind ") == true, "human readably message expected" )
    }

    func test05_WindToLive() throws {
        try AudioPlayer.open(for: ybridSwr3Endpoint, listener: ybridPlayerListener,
             playbackControl: failOnPlaybackControl,
             ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)

                ybridControl.wind(by:-20.0)
                wait(ybridPlayerListener, shifted: -20.0, maxSeconds: maxWindResponseS)
                sleep(4)
                ybridControl.windToLive()
                wait(ybridPlayerListener, shifted: 0.0, maxSeconds: maxWindResponseS)
                sleep(4)
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: maxWindResponseS)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertGreaterThanOrEqual(ybridPlayerListener.offsets.count, 3, "expected to be at least the initial and two more changes of offset")
        guard let lastOffset = ybridPlayerListener.offsets.last else {
            XCTFail(); return
        }
        XCTAssertTrue(liveOffsetRange_LostSign.contains(-lastOffset), "\(-lastOffset) not within \(liveOffsetRange_LostSign)")
        
    }
    
    func test06_WindToDate_BeforeFullHourAdvertisement() throws {
        try AudioPlayer.open(for: ybridSwr3Endpoint, listener: ybridPlayerListener,
             playbackControl: failOnPlaybackControl,
             ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
        
                let date = lastFullHour(secondsBefore:15)
                ybridControl.wind(to:date)
                wait(ybridControl, type: ItemType.ADVERTISEMENT, maxSeconds: Int(YbridTimeshiftTests.maxWindComplete))
                sleep(4)

                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: maxWindResponseS)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
    }
    
    
    func test07_SkipBackwardNews_SkipForwardMusic() throws {
        try AudioPlayer.open(for: ybridSwr3Endpoint, listener: ybridPlayerListener,
             playbackControl: failOnPlaybackControl,
             ybridControl: { [self] (ybridControl) in
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
        
                ybridControl.skipBackward(ItemType.NEWS)
                wait(ybridControl, type: ItemType.NEWS, maxSeconds: Int(YbridTimeshiftTests.maxWindComplete))
                sleep(8)
  
                ybridControl.skipForward(ItemType.MUSIC)
                wait(ybridControl, type: ItemType.MUSIC, maxSeconds: Int(YbridTimeshiftTests.maxWindComplete))
                sleep(6)
                
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
    }
    
    func test08_SkipBackwardItem_LastItemAgain() throws {
        try AudioPlayer.open(for: ybridSwr3Endpoint, listener: ybridPlayerListener,
             playbackControl: failOnPlaybackControl,
             ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
        
                ybridControl.skipBackward()
                let type = ybridPlayerListener.metadatas.last?.current?.type
                XCTAssertNotNil(type)
                Logger.testing.notice("currently playing \(type ?? ItemType.UNKNOWN)")

                sleep(4)
  
                ybridControl.skipBackward()
                let typeNow = ybridPlayerListener.metadatas.last?.current?.type
                XCTAssertEqual(type, typeNow)
                Logger.testing.notice("again playing \(type ?? ItemType.UNKNOWN)")

                sleep(4)
                
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
    }
   
    private func shift( _ range:Range<TimeInterval>, by:TimeInterval ) -> Range<TimeInterval> {
        let shiftedRange = range.lowerBound+by ..< range.upperBound+by
        return shiftedRange
    }

    private func wait(_ consumer:TestYbridPlayerListener, shifted: TimeInterval, maxSeconds:Int) {
        let shiftedRange_LostSign = shift(liveOffsetRange_LostSign, by: -shifted)
        let took = wait(max: maxSeconds) {
            guard let offset = consumer.offsetToLive else {
                return false
            }
            return isOffset(offset, shifted: shifted)
        }
        XCTAssertLessThanOrEqual(took, maxSeconds, "offset to live not \((-shiftedRange_LostSign.lowerBound).S) ..< \((-shiftedRange_LostSign.upperBound).S) within \(maxSeconds) s")
    }
    
    private func wait(_ control:YbridControl, type: ItemType, maxSeconds:Int) {

        let took = wait(max: maxSeconds) {
            return ybridPlayerListener.isItem(type)
        }
        XCTAssertLessThanOrEqual(took, maxSeconds, "item type is \(String(describing: ybridPlayerListener.metadatas.last?.current?.type)), not \(type)")
    }
    
    
    private func wait(_ control:YbridControl, until:PlaybackState, maxSeconds:Int) {
        let took = wait(max: maxSeconds) {
            return control.state == until
        }
        XCTAssertLessThanOrEqual(took, maxSeconds, "not \(until) within \(maxSeconds) s")
    }
    
    private func wait(max maxSeconds:Int, until:() -> (Bool)) -> Int {
        var seconds = 0
        while !until() && seconds <= maxSeconds {
            sleep(1)
            seconds += 1
        }
        XCTAssertTrue(until(), "condition not satisfied within \(maxSeconds) s")
        return seconds
    }
    
    func isOffset(_ offset:TimeInterval, shifted:TimeInterval) -> Bool {
        let shiftedRange_LostSign = shift(liveOffsetRange_LostSign, by: -shifted)
        return shiftedRange_LostSign.contains(-offset)
    }

    
    
    // MARK: using audio callback
    
    func test11_WindBackWindLive_Swr3() throws {

        let actionTraces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ (ybrid) in
            actionTraces.append( windSynced(by:-300, ybrid, maxWait: 15.0) )
            actionTraces.append( windSynced(to:nil, ybrid, maxWait: 15.0) )
        }

        checkErrors(expectedErrors: 0)
        actionTraces.check(expectedActions: 2, maxDuration: YbridTimeshiftTests.maxWindComplete)
    }
    
    func test12_WindToWindForward_Swr3() throws {

        let actionTraces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ (ybrid) in
            let date = self.lastFullHour(secondsBefore:-4)
            actionTraces.append( windSynced(to:date, ybrid) )
            actionTraces.append( windSynced(by:30, ybrid) )
        }

        checkErrors(expectedErrors: 0)
        actionTraces.check(expectedActions: 2, maxDuration: YbridTimeshiftTests.maxWindComplete)
    }
    
    func test13_SkipBackNewsSkipMusic_Swr3() throws {

        let actionTraces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ (ybrid) in
            actionTraces.append( skipSynced(-1, to:ItemType.NEWS, ybrid) )
            actionTraces.append( skipSynced(+1, to:ItemType.MUSIC, ybrid) )
        }

        checkErrors(expectedErrors: 0)
        actionTraces.check(expectedActions: 2, maxDuration: YbridTimeshiftTests.maxWindComplete)
    }
    
    func test13b_SkipBackItem_Swr3() throws {

        let actionTraces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ (ybrid) in
            actionTraces.append( skipSynced(-1, to:nil, ybrid, maxWait: 15.0) )
        }

        checkErrors(expectedErrors: 0)
        actionTraces.check(expectedActions: 1, maxDuration: YbridTimeshiftTests.maxWindComplete)
    }
    
    func test14_windLiveWhenLive() throws {

        let traces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ (ybrid) in
            traces.append( windSynced(to:nil, ybrid, maxWait: 15.0) )
        }

        checkErrors(expectedErrors: 0)
        traces.check(expectedActions: 1, maxDuration: YbridTimeshiftTests.maxWindComplete)
    }
    
    
    func test21_windBack10Times() throws {

        let traces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ (ybrid) in
            traces.append( windSynced(by:-201, ybrid) )
            traces.append( windSynced(by:-202, ybrid) )
            traces.append( windSynced(by:-203, ybrid) )
            traces.append( windSynced(by:-204, ybrid) )
            traces.append( windSynced(by:-205, ybrid) )
            traces.append( windSynced(by:-206, ybrid) )
            traces.append( windSynced(by:-207, ybrid) )
            traces.append( windSynced(by:-208, ybrid) )
            traces.append( windSynced(by:-209, ybrid) )
            traces.append( windSynced(by:-210, ybrid) )
        }

        checkErrors(expectedErrors: 0)
        traces.check(expectedActions: 10, maxDuration: YbridTimeshiftTests.maxWindComplete)
    }

    func test22_windForward10Times() throws {

        let traces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ (ybrid) in
            traces.append( windSynced(by:-3600, ybrid) )
            traces.append( windSynced(by:101, ybrid) )
            traces.append( windSynced(by:102, ybrid) )
            traces.append( windSynced(by:103, ybrid) )
            traces.append( windSynced(by:104, ybrid) )
            traces.append( windSynced(by:105, ybrid) )
            traces.append( windSynced(by:106, ybrid) )
            traces.append( windSynced(by:107, ybrid) )
            traces.append( windSynced(by:108, ybrid) )
            traces.append( windSynced(by:109, ybrid) )
            traces.append( windSynced(by:110, ybrid) )
        }

        checkErrors(expectedErrors: 0)
        traces.check(expectedActions: 11, maxDuration: YbridTimeshiftTests.maxWindComplete)
    }
    
    func test23_skip5Back5Forward() throws {

        let traces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ (ybrid) in
            traces.append( windSynced(by:-3600, ybrid) )
            traces.append( skipSynced(-1, to:nil, ybrid) )
            traces.append( skipSynced(-1, to:nil, ybrid) )
            traces.append( skipSynced(-1, to:nil, ybrid) )
            traces.append( skipSynced(-1, to:nil, ybrid) )
            traces.append( skipSynced(-1, to:nil, ybrid) )
            traces.append( skipSynced(+1, to:nil, ybrid) )
            traces.append( skipSynced(+1, to:nil, ybrid) )
            traces.append( skipSynced(+1, to:nil, ybrid) )
            traces.append( skipSynced(+1, to:nil, ybrid) )
            traces.append( skipSynced(+1, to:nil, ybrid) )
        }
        
        checkErrors(expectedErrors: 0)
        traces.check(expectedActions: 11, maxDuration: YbridTimeshiftTests.maxWindComplete)
    }


    // MARK: test helpers
    
    func lastFullHour(secondsBefore:Int) -> Date {
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
    
    private func checkErrors(expectedErrors:Int)  {
        guard ybridPlayerListener.errors.count == expectedErrors else {
            XCTFail("\(expectedErrors) errors expected, but were \(ybridPlayerListener.errors.count)")
            ybridPlayerListener.errors.forEach { (err) in
                let errMessage = err.localizedDescription
                Logger.testing.error("error is \(errMessage)")
            }
            return
        }
    }
    
}

fileprivate func windSynced(by:TimeInterval, _ ybrid:YbridControl, maxWait:TimeInterval? = nil) -> (Trace) {
    let mySema = DispatchSemaphore(value: 0)
    let trace = Trace("wind by \(by.S)")
    ybrid.wind(by: by ) { (success) in
        timeshiftComplete(success, trace)
        mySema.signal()
    }
    if let maxWait = maxWait {
        _ = mySema.wait(timeout: .now() + maxWait)
    } else {
        _ = mySema.wait(timeout: .distantFuture)
    }
    return trace
}

fileprivate func windSynced(to:Date?, _ ybrid:YbridControl, maxWait:TimeInterval? = nil) -> (Trace) {
    let mySema = DispatchSemaphore(value: 0)
    let trace:Trace
    if let date = to {
        trace = Trace("wind to \(date)")
        ybrid.wind(to: date ) { (success) in
            timeshiftComplete(success, trace)
            mySema.signal()
        }
    } else {
        trace = Trace("wind live")
        ybrid.windToLive() { (success) in
            timeshiftComplete(success, trace)
            mySema.signal()
        }
    }
    if let maxWait = maxWait {
        _ = mySema.wait(timeout: .now() + maxWait)
    } else {
        _ = mySema.wait(timeout: .distantFuture)
    }
    return trace
}

fileprivate func skipSynced(_ count:Int, to type:ItemType? = nil, _ ybrid:YbridControl, maxWait:TimeInterval? = nil) -> Trace {
    guard count == 1 || count == -1 else {
        Logger.testing.error("skip \(count) not supported")
        return Trace("denied skipping \(count) to \(String(describing: type))")
    }
    let mySema = DispatchSemaphore(value: 0)
    let trace:Trace
    if count == 1 {
        if let type = type {
            trace = Trace("skip forward to \(type)")
            ybrid.skipForward(type) { (success) in
                timeshiftComplete(success, trace)
                mySema.signal()
            }
        } else {
            trace = Trace("skip forward to item")
            ybrid.skipForward() { (success) in
                timeshiftComplete(success, trace)
                mySema.signal()
            }
    }} else {
        if let type = type {
            trace = Trace("skip backward to \(type)")
            ybrid.skipBackward(type) { (success) in
                timeshiftComplete(success, trace)
                mySema.signal()
            }
        } else {
            trace = Trace("skip backward to item")
            ybrid.skipBackward() { (success) in
                timeshiftComplete(success, trace)
                mySema.signal()
            }
    }}
    if let maxWait = maxWait {
        _ = mySema.wait(timeout: .now() + maxWait)
    } else {
        _ = mySema.wait(timeout: .distantFuture)
    }
    return trace
}

fileprivate func timeshiftComplete(_ success:Bool,_ trace:Trace) {
   trace.complete(success)
   Logger.testing.notice( "***** audio complete ***** did \(success ? "":"not ")\(trace.name)")
   sleep(3)
}

