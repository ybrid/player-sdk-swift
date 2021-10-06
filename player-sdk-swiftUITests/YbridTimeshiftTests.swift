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

    let maxWindChanged = 2.0
    let maxWindChangedS = 2
    let maxControlChangedS = 2

    let icyMaxInterval:TimeInterval = 15.0
    let liveOffsetRange_LostSign = TimeInterval(0.0) ..< TimeInterval(10.0)

    let listener = TestYbridPlayerListener()
    var testControl:TestYbridControl?
    override func setUpWithError() throws {
        listener.logPlayingSince = false
        listener.logBufferSize = false
        listener.logMetadata = false
        
        testControl = TestYbridControl(ybridSwr3Endpoint, listener: listener)
    }
    override func tearDownWithError() throws {
        print( "offsets were \(listener.offsets)")
        listener.reset()
    }
    
    func test01_InitialOffsetChange() throws {
        
        testControl!.stopped{ (ybrid) in
            usleep(20_000)
        }
        
        XCTAssertEqual(listener.offsets.count, 1)
    }
    
    func test02_PlayOffsetChanges() throws {
        
        testControl!.stopped{ [self] (ybrid) in
            
            ybrid.play()
            wait(testControl!.ctrl!, until: PlaybackState.playing, maxSeconds: 10)
            sleep(2)
            ybrid.stop()
            wait(ybrid, until: PlaybackState.stopped, maxSeconds: 2)
        }
        
        XCTAssertGreaterThanOrEqual(listener.offsets.count, 2)
        listener.offsets.forEach{
            XCTAssertTrue(liveOffsetRange_LostSign.contains(-$0))
        }
    }
    
    func test03_WindBackward120_WindForward60_failsOccasionally() throws {
        testControl!.playing{ [self] (ybrid) in
            _ = wait(max: 2) { listener.bufferS != 0 } /// ensure the buffer is filled
            let bufferS = listener.bufferS
            let maxAudioComplete: Int = bufferS + maxWindChangedS
            Logger.testing.info("buffer duration <= \(bufferS) s, max audio complete \(maxAudioComplete) s")
            
            ybrid.wind(by: -120.0)
            /// the first notification of expected offset occurs early, with the response of change request, it may be not precise
            wait(listener, shifted: -120.0, maxSeconds: maxControlChangedS)
            sleep(UInt32(maxAudioComplete))
            
            ybrid.wind(by: 60.0)
            /// the first notification of expected offset occurs early, with the response of change request, it may be not precise
            wait(listener, shifted: -60.0, maxSeconds: maxControlChangedS)
            sleep(UInt32(maxAudioComplete))
        }
        
        XCTAssertGreaterThanOrEqual(listener.offsets.count, 2, "expected to be at least the initial and one more change of offset")
        guard let lastOffset = listener.offsets.last else {
            XCTFail(); return
        }
        let shiftedRangeNegated = shift(liveOffsetRange_LostSign, by: +60.0)
        XCTAssertTrue(shiftedRangeNegated.contains(-lastOffset), "\(-lastOffset) not within \(shiftedRangeNegated)") // occasionally some ms
    }
    
    func test04_Wind_Cannot() throws {
        let testAdDemo = TestYbridControl(ybridAdDemoEndpoint, listener: listener)
        testAdDemo.playing{ [self] (ybrid) in
            
            ybrid.wind(by: -120.0)
            sleep(UInt32(maxControlChangedS))
        }
        
        XCTAssertGreaterThanOrEqual(listener.offsets.count, 1, "expected to be only the initial change of offset")
        guard let lastOffset = listener.offsets.last else {
            XCTFail(); return
        }
        let shiftedRangeNegated = shift(liveOffsetRange_LostSign, by: 0.0)
        XCTAssertTrue(shiftedRangeNegated.contains(-lastOffset), "\(-lastOffset) not within \(shiftedRangeNegated)")
        
        guard let error = listener.errors.last else {
            XCTFail( "expected an error message"); return
        }
        XCTAssertTrue(error.message?.contains("cannot wind ") == true, "human readably message expected" )
    }

    func test05_WindToLive() throws {
        testControl!.playing{ [self] (ybrid) in
            usleep(200_000)
            let bufferS = listener.bufferS
            let maxAudioComplete: Int = bufferS + maxWindChangedS
            Logger.testing.info("buffer duration \(bufferS) s, max audio complete \(maxAudioComplete) s")

            ybrid.wind(by:-20.0)
            wait(listener, shifted: -20.0, maxSeconds: maxControlChangedS)
            sleep(UInt32(maxAudioComplete))
            
            ybrid.windToLive()
            wait(listener, shifted: 0.0, maxSeconds: maxControlChangedS)
            sleep(UInt32(maxAudioComplete))
        }

        XCTAssertGreaterThanOrEqual(listener.offsets.count, 3, "expected to be at least the initial and two more changes of offset")
        guard let lastOffset = listener.offsets.last else {
            XCTFail(); return
        }
        XCTAssertTrue(liveOffsetRange_LostSign.contains(-lastOffset), "\(-lastOffset) not within \(liveOffsetRange_LostSign)")
        
    }
    
    func test06_WindToDate_BeforeFullHourAdvertisement__failsInTheNight() throws {
        testControl!.playing{ [self] (ybrid) in
            usleep(200_000)
            let buffer = listener.bufferDuration ?? 0.0
            let maxAudioComplete = buffer + maxWindChanged
            Logger.testing.info("buffer duration \(buffer.S), max audio complete \(maxAudioComplete.S)")
            
            let date = self.lastFullHour(secondsBefore:15)
            ybrid.wind(to:date)
            
            waitUntil(ybrid, in: [ItemType.ADVERTISEMENT], maxSeconds: maxAudioComplete)
        }
    }
    
    // fails during news
    func test07_SkipBackwardNews_SkipForwardMusic_ok() throws {
        testControl!.playing{ [self] (ybrid) in
            usleep(200_000)
            let buffer = listener.bufferDuration ?? 0.0
            let maxAudioComplete = buffer + maxWindChanged
            Logger.testing.info("buffer duration \(buffer.S), max audio complete \(maxAudioComplete.S)")
            
            ybrid.skipBackward(ItemType.NEWS)
            waitUntil(ybrid, in:[ItemType.NEWS], maxSeconds: maxAudioComplete)

            ybrid.skipForward(ItemType.MUSIC)
            waitUntil(ybrid, in:[ItemType.MUSIC], maxSeconds: maxAudioComplete)
            
            sleep(UInt32(maxAudioComplete))
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
            return listener.isItem(of: types)
        }
        XCTAssertLessThanOrEqual(took, roundedUp, "item type is \(String(describing: listener.metadatas.last?.current?.type)), not in \(types)")
    }
        
    private func wait(_ control:PlaybackControl, until:PlaybackState, maxSeconds:Int) {
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
    
    func test11_WindBackWindLive_ok() throws {

        guard let test = testControl else {
            XCTFail("cannot use ybrid test control."); return
        }
        
        var maxWait:maxValues = (0.0, 0.0)
        test.playing{ (ybrid) in
            maxWait = self.durations()
            
            test.windSynced(by:-300)
            test.windSynced(to:nil)
        }

        test.checkErrors(expected: 0)
            .checkAllActions(confirm: 2, withinS: maxWait.complete)
    }
    
    typealias maxValues = (buffer:TimeInterval, complete:TimeInterval)
    private func durations() -> maxValues {

        _ = wait(max: 3) { listener.bufferDuration != nil }
        let buffer = listener.bufferDuration ?? 0.0
        let maxAudioComplete = buffer + maxWindChanged
        Logger.testing.info("buffer duration \(buffer.S), max audio complete \(maxAudioComplete.S)")
        return (buffer, maxAudioComplete)
    }
    
    func test12_WindToWindForward__fails() throws {
        guard let test = testControl else {
            XCTFail("cannot use ybrid test control."); return
        }
        
        var maxWait:maxValues = (0.0,0.0)
        test.playing{ (ybrid) in
            maxWait = self.durations()
  
            let date = self.lastFullHour(secondsBefore:-4)
            test.windSynced(to:date)
            test.windSynced(by:30, maxWait: maxWait.complete)
        }

        test.checkErrors(expected: 0)
            .checkAllActions(confirm: 2, withinS: maxWait.complete)
    }
    
    // fails during news
    func test13_SkipBackNewsSkipMusic_ok() throws {
        guard let test = testControl else {
            XCTFail("cannot use ybrid test control."); return
        }

        var maxWait:maxValues = (0.0,0.0)
        test.playing{ (ybrid) in
            maxWait = self.durations()
            test.skipSynced(-1, to:ItemType.NEWS)
            test.skipSynced(+1, to:ItemType.MUSIC)
        }

        test.checkErrors(expected: 0)
            .checkAllActions(confirm: 2, withinS: maxWait.complete)
    }
    
    func test14_SkipBackItem__fails() throws {
        guard let test = testControl else {
            XCTFail("cannot use ybrid test control."); return
        }

        var maxWait:maxValues = (0.0,0.0)
        test.playing{ (ybrid) in
            maxWait = self.durations()
            test.skipSynced(-1, to:nil, maxWait: maxWait.complete)
        }

        test.checkErrors(expected: 0)
            .checkAllActions(confirm: 1, withinS: maxWait.complete)
    }
    
    func test15_windLiveWhenLive__fails() throws {
        guard let test = testControl else {
            XCTFail("cannot use ybrid test control."); return
        }
        var maxWait:maxValues = (0.0,0.0)
        test.playing{ (ybrid) in
            maxWait = self.durations()
            test.windSynced(to:nil, maxWait: maxWait.complete)
        }

        test.checkErrors(expected: 0)
            .checkAllActions(confirm: 1, withinS: maxWait.complete)
    }
    
    func test16_SkipBackwardItem_LastItemAgain__fails() throws {
        guard let test = testControl else {
            XCTFail("cannot use ybrid test control."); return
        }
        
        var maxWait:maxValues = (0.0,0.0)
        test.playing{ [self] (ybrid) in
            maxWait = durations()
            
            let typeBegin = test.listener.metadatas.last?.current?.type
            XCTAssertNotNil(typeBegin)
            Logger.testing.notice("-- playing \(typeBegin ?? ItemType.UNKNOWN)")
            
            
            test.skipSynced(-1, to: nil, maxWait: icyMaxInterval)
            
            let typeBack1 = test.listener.metadatas.last?.current?.type
            XCTAssertNotNil(typeBack1)
            Logger.testing.notice("-- playing \(typeBack1 ?? ItemType.UNKNOWN)")
  
            
            test.skipSynced( -1, to: nil, maxWait: icyMaxInterval)
            
            let typeBack2 = test.listener.metadatas.last?.current?.type
            XCTAssertNotNil(typeBack2)
            Logger.testing.notice("-- playing \(typeBack2 ?? ItemType.UNKNOWN)")

            XCTAssertEqual(typeBack1, typeBack2)
        }

        test.checkErrors(expected: 0)
            .checkAllActions(confirm: 2, withinS: maxWait.complete)
    }
    
    func test21_windBack10Times() throws {
        guard let test = testControl else {
            XCTFail("cannot use ybrid test control."); return
        }
        
        var maxWait:maxValues = (0.0,0.0)
        test.playing{ (ybrid) in
            maxWait = self.durations()
            
            test.windSynced(by:-201)
            test.windSynced(by:-202)
            test.windSynced(by:-203)
            test.windSynced(by:-204)
            test.windSynced(by:-205)
            test.windSynced(by:-206)
            test.windSynced(by:-207)
            test.windSynced(by:-208)
            test.windSynced(by:-209)
            test.windSynced(by:-210)
        }

        test.checkErrors(expected: 0)
            .checkAllActions(confirm: 10, withinS: maxWait.complete)
    }

    func test22_windForward10Times() throws {
        guard let test = testControl else {
            XCTFail("cannot use ybrid test control."); return
        }
        
        var maxWait:maxValues = (0.0,0.0)
        test.playing{ (ybrid) in
            maxWait = self.durations()
            
            test.windSynced(by:-3600)
            test.windSynced(by:101)
            test.windSynced(by:102)
            test.windSynced(by:103)
            test.windSynced(by:104)
            test.windSynced(by:105)
            test.windSynced(by:106)
            test.windSynced(by:107)
            test.windSynced(by:108)
            test.windSynced(by:109)
            test.windSynced(by:110)
        }

        test.checkErrors(expected: 0)
            .checkAllActions(confirm: 11, withinS: maxWait.complete)

    }
    
    func test23_skip5Back5Forward() throws {
        guard let test = testControl else {
            XCTFail("cannot use ybrid test control."); return
        }
        
        var maxWait:maxValues = (0.0,0.0)
        test.playing{ (ybrid) in
            maxWait = self.durations()
            
            test.windSynced(by:-3600)
            test.skipSynced(-1, to:nil)
            test.skipSynced(-1, to:nil)
            test.skipSynced(-1, to:nil)
            test.skipSynced(-1, to:nil)
            test.skipSynced(-1, to:nil)
            test.skipSynced(+1, to:nil)
            test.skipSynced(+1, to:nil)
            test.skipSynced(+1, to:nil)
            test.skipSynced(+1, to:nil)
            test.skipSynced(+1, to:nil)
        }
        
        test.checkErrors(expected: 0)
            .checkAllActions(confirm: 11, withinS: maxWait.complete)
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


fileprivate func timeshiftComplete(_ success:Bool,_ trace:Trace) {
   trace.complete(success)
   Logger.testing.notice( "***** audio complete ***** did \(success ? "":"not ")\(trace.name)")
   sleep(3)
}
