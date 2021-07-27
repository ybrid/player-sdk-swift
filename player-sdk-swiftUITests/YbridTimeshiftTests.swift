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

    let maxWindComplete = 4.0
    let maxWindResponseS = 2
    var maxWindCompleteS: UInt32 { get { return UInt32(maxWindComplete)+1 }}
    let liveOffsetRange_LostSign = TimeInterval(0.0) ..< TimeInterval(10.0)

    let ybridPlayerListener = TestYbridPlayerListener()
    
    var semaphore:DispatchSemaphore?
    override func setUpWithError() throws {
        semaphore = DispatchSemaphore(value: 0)
    }    
    override func tearDownWithError() throws {
        print( "offsets were \(ybridPlayerListener.offsets)")
        ybridPlayerListener.reset()
    }
    
    func test01_InitialOffsetChange() throws {
        
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).stopped{ (ybrid) in
            usleep(20_000)
        }
        
        XCTAssertEqual(ybridPlayerListener.offsets.count, 1)
    }
    
    func test02_PlayOffsetChanges() throws {
        
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).stopped{ [self] (ybrid) in
            
            ybrid.play()
            wait(ybrid, until: PlaybackState.playing, maxSeconds: 10)
            sleep(2)
            ybrid.stop()
            wait(ybrid, until: PlaybackState.stopped, maxSeconds: 2)
        }
        
        XCTAssertGreaterThanOrEqual(ybridPlayerListener.offsets.count, 2)
        ybridPlayerListener.offsets.forEach{
            XCTAssertTrue(liveOffsetRange_LostSign.contains(-$0))
        }
    }
    
    func test03_WindBackward120_WindForward60() throws {
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ [self] (ybrid, test) in
            
            ybrid.wind(by: -120.0)
            wait(ybridPlayerListener, shifted: -120.0, maxSeconds: maxWindResponseS)
            sleep(maxWindCompleteS)
            
            ybrid.wind(by: 60.0)
            wait(ybridPlayerListener, shifted: -60.0, maxSeconds: maxWindResponseS)
            sleep(maxWindCompleteS)
        }

        
        XCTAssertGreaterThanOrEqual(ybridPlayerListener.offsets.count, 2, "expected to be at least the initial and one more change of offset")
        guard let lastOffset = ybridPlayerListener.offsets.last else {
            XCTFail(); return
        }
        let shiftedRangeNegated = shift(liveOffsetRange_LostSign, by: +60.0)
        XCTAssertTrue(shiftedRangeNegated.contains(-lastOffset), "\(-lastOffset) not within \(shiftedRangeNegated)")
    }
    
    
    func test04_Wind_Cannot() throws {
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ [self] (ybrid, test) in
            
            ybrid.wind(by: -120.0)
            sleep(maxWindCompleteS)
        }

        
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
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ [self] (ybrid, test) in
            
            ybrid.wind(by:-20.0)
            wait(ybridPlayerListener, shifted: -20.0, maxSeconds: maxWindResponseS)
            sleep(maxWindCompleteS)
            
            ybrid.windToLive()
            wait(ybridPlayerListener, shifted: 0.0, maxSeconds: maxWindResponseS)
            sleep(maxWindCompleteS)
        }

        
        XCTAssertGreaterThanOrEqual(ybridPlayerListener.offsets.count, 3, "expected to be at least the initial and two more changes of offset")
        guard let lastOffset = ybridPlayerListener.offsets.last else {
            XCTFail(); return
        }
        XCTAssertTrue(liveOffsetRange_LostSign.contains(-lastOffset), "\(-lastOffset) not within \(liveOffsetRange_LostSign)")
        
    }
    
    func test06_WindToDate_BeforeFullHourAdvertisement__failsInTheNight() throws {
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ [self] (ybrid, test) in
            
            let date = self.lastFullHour(secondsBefore:15)
            ybrid.wind(to:date)
            waitUntil(ybrid, in: [ItemType.ADVERTISEMENT], maxSeconds: maxWindComplete)
        }
    }
    
    func test07_SkipBackwardNews_SkipForwardMusic() throws {
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ [self] (ybrid, test) in
            
            ybrid.skipBackward(ItemType.NEWS)
            waitUntil(ybrid, in:[ItemType.NEWS], maxSeconds: maxWindComplete)

            ybrid.skipForward(ItemType.MUSIC)
            waitUntil(ybrid, in:[ItemType.MUSIC], maxSeconds: maxWindComplete)
        }
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
    
    private func waitUntil(_ control:YbridControl, in types: [ItemType], maxSeconds:TimeInterval) {

        let roundedUp = Int(maxSeconds) + 1
        let took = wait(max: roundedUp) {
            return ybridPlayerListener.isItem(of: types)
        }
        XCTAssertLessThanOrEqual(took, roundedUp, "item type is \(String(describing: ybridPlayerListener.metadatas.last?.current?.type)), not in \(types)")
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
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ (ybrid, test) in
            actionTraces.append( test!.windSynced(by:-300) )
            actionTraces.append( test!.windSynced(to:nil) )
        }

        checkErrors(expectedErrors: 0)
        actionTraces.check(confirm: 2, maxDuration: maxWindComplete)
    }
    
    func test12_WindToWindForward_Swr3__failsOften() throws {

        let actionTraces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ (ybrid,test) in
            let date = self.lastFullHour(secondsBefore:-4)
            actionTraces.append( test!.windSynced(to:date) )
            actionTraces.append( test!.windSynced(by:30, maxWait: 15.0) )
        }

        checkErrors(expectedErrors: 0)
        actionTraces.check(confirm: 2, maxDuration: maxWindComplete)
    }
    
    func test13_SkipBackNewsSkipMusic_Swr3() throws {

        let actionTraces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ (ybrid,test) in
            actionTraces.append( test!.skipSynced(-1, to:ItemType.NEWS) )
            actionTraces.append( test!.skipSynced(+1, to:ItemType.MUSIC) )
        }

        checkErrors(expectedErrors: 0)
        actionTraces.check(confirm: 2, maxDuration: maxWindComplete)
    }
    
    func test14_SkipBackItem_Swr3__failsSometimes() throws {

        let actionTraces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ (ybrid, test) in

            actionTraces.append( test!.skipSynced(-1, to:nil, maxWait: 15.0) )
        }

        checkErrors(expectedErrors: 0)
        actionTraces.check(confirm: 1, maxDuration: maxWindComplete)
    }
    
    func test15_windLiveWhenLive__fails() throws {

        let traces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ (ybrid,test) in
            traces.append( test!.windSynced(to:nil, maxWait: 15.0) )
        }

        checkErrors(expectedErrors: 0)
        traces.check(confirm: 1, maxDuration: maxWindComplete)
    }
    
    func test16_SkipBackwardItem_LastItemAgain__failsOften() throws {
       
        let traces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ [self] (ybrid,test) in
            
            let typeBegin = ybridPlayerListener.metadatas.last?.current?.type
            XCTAssertNotNil(typeBegin)
            Logger.testing.notice("-- playing \(typeBegin ?? ItemType.UNKNOWN)")
            
            
            traces.append( test!.skipSynced(-1, to: nil, maxWait: 15.0) )
            
            let typeBack1 = ybridPlayerListener.metadatas.last?.current?.type
            XCTAssertNotNil(typeBack1)
            Logger.testing.notice("-- playing \(typeBack1 ?? ItemType.UNKNOWN)")
  
            
            traces.append( test!.skipSynced( -1, to: nil, maxWait: 15.0) )
            
            let typeBack2 = ybridPlayerListener.metadatas.last?.current?.type
            XCTAssertNotNil(typeBack2)
            Logger.testing.notice("-- playing \(typeBack2 ?? ItemType.UNKNOWN)")

            XCTAssertEqual(typeBack1, typeBack2)
        }

        checkErrors(expectedErrors: 0)
        traces.check(confirm: 2, maxDuration: maxWindComplete)
    }
 
    
    func test21_windBack10Times() throws {

        let traces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ (ybrid,test) in
            traces.append( test!.windSynced(by:-201) )
            traces.append( test!.windSynced(by:-202) )
            traces.append( test!.windSynced(by:-203) )
            traces.append( test!.windSynced(by:-204) )
            traces.append( test!.windSynced(by:-205) )
            traces.append( test!.windSynced(by:-206) )
            traces.append( test!.windSynced(by:-207) )
            traces.append( test!.windSynced(by:-208) )
            traces.append( test!.windSynced(by:-209) )
            traces.append( test!.windSynced(by:-210) )
        }

        checkErrors(expectedErrors: 0)
        traces.check(confirm: 10, maxDuration: maxWindComplete)
    }

    func test22_windForward10Times() throws {

        let traces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ (ybrid,test) in
            traces.append( test!.windSynced(by:-3600) )
            traces.append( test!.windSynced(by:101) )
            traces.append( test!.windSynced(by:102) )
            traces.append( test!.windSynced(by:103) )
            traces.append( test!.windSynced(by:104) )
            traces.append( test!.windSynced(by:105) )
            traces.append( test!.windSynced(by:106) )
            traces.append( test!.windSynced(by:107) )
            traces.append( test!.windSynced(by:108) )
            traces.append( test!.windSynced(by:109) )
            traces.append( test!.windSynced(by:110) )
        }

        checkErrors(expectedErrors: 0)
        traces.check(confirm: 11, maxDuration: maxWindComplete)
    }
    
    func test23_skip5Back5Forward() throws {

        let traces = ActionsTrace()
        TestYbridControl(ybridSwr3Endpoint, listener: ybridPlayerListener).playing{ (ybrid,test) in
            traces.append( test!.windSynced(by:-3600) )
            traces.append( test!.skipSynced(-1, to:nil) )
            traces.append( test!.skipSynced(-1, to:nil) )
            traces.append( test!.skipSynced(-1, to:nil) )
            traces.append( test!.skipSynced(-1, to:nil) )
            traces.append( test!.skipSynced(-1, to:nil) )
            traces.append( test!.skipSynced(+1, to:nil) )
            traces.append( test!.skipSynced(+1, to:nil) )
            traces.append( test!.skipSynced(+1, to:nil) )
            traces.append( test!.skipSynced(+1, to:nil) )
            traces.append( test!.skipSynced(+1, to:nil) )
        }
        
        checkErrors(expectedErrors: 0)
        traces.check(confirm: 11, maxDuration: maxWindComplete)
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
                Logger.testing.error("-- error is \(errMessage)")
            }
            return
        }
    }
    
}


fileprivate func timeshiftComplete(_ success:Bool,_ trace:Trace) {
   trace.complete(success)
   Logger.testing.notice( "***** audio complete ***** did \(success ? "":"not ")\(trace.name)")
   sleep(3)
}

