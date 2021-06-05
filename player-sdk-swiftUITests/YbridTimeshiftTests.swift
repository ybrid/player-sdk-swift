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

    let liveOffsetRange_LostSign = TimeInterval(0.0) ..< TimeInterval(10.0)
    let maxWindResponseS = 2
    
    var player:YbridControl?
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
    
    func test01_YbridControl_GettingOffset_NoListener() throws {
        
        try AudioPlayer.open(for: ybridStageSwr3Endpoint, listener: nil,
               ybridControl: { [self] (ybridControl) in
                
                let offset = ybridControl.offsetToLiveS
                Logger.testing.notice("offset to live is \(offset.S)")
                XCTAssertTrue(liveOffsetRange_LostSign.contains(-offset))
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertEqual(ybridPlayerListener.offsetChanges, 0)
    }
    
    func test02_YbridControl_ListeningToOffsetChanges() throws {
        
        try AudioPlayer.open(for: ybridStageSwr3Endpoint, listener: ybridPlayerListener,
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertGreaterThanOrEqual(ybridPlayerListener.offsetChanges, 1)
        ybridPlayerListener.offsets.forEach{
            XCTAssertTrue(liveOffsetRange_LostSign.contains(-$0))
        }
    }
    
    func test03_YbridControl_WindBackward120Forward60() throws {
        try AudioPlayer.open(for: ybridStageSwr3Endpoint, listener: ybridPlayerListener,
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
        
                ybridControl.wind(by: -120.0)
                wait(ybridControl, shifted: -120.0, maxSeconds: 2)
                sleep(4)
                
                ybridControl.wind(by: 60.0)
                wait(ybridControl, shifted: -60.0, maxSeconds: 2)
                sleep(4)
                
                
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertGreaterThanOrEqual(ybridPlayerListener.offsetChanges, 2, "expected to be at least the initial and one more change of offset")
        guard let lastOffset = ybridPlayerListener.offsets.last else {
            XCTFail(); return
        }
        let shiftedRangeNegated = shift(liveOffsetRange_LostSign, by: +60.0)
        XCTAssertTrue(shiftedRangeNegated.contains(-lastOffset), "\(-lastOffset) not within \(shiftedRangeNegated)")
    }
    
    
    func test04_YbridControl_CannotWind() throws {
        try AudioPlayer.open(for: ybridDemoEndpoint, listener: ybridPlayerListener,
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
        
        XCTAssertGreaterThanOrEqual(ybridPlayerListener.offsetChanges, 1, "expected to be only the initial change of offset")
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

    func test05_YbridControl_WindToLive() throws {
        try AudioPlayer.open(for: ybridStageSwr3Endpoint, listener: ybridPlayerListener,
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
                ybridControl.wind(by:-20.0)
                wait(ybridControl, shifted: -20.0, maxSeconds: maxWindResponseS)
                sleep(4)
                ybridControl.windToLive()
                wait(ybridControl, shifted: 0.0, maxSeconds: maxWindResponseS)
                sleep(4)
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: maxWindResponseS)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
        
        XCTAssertGreaterThanOrEqual(ybridPlayerListener.offsetChanges, 3, "expected to be at least the initial and two more changes of offset")
        guard let lastOffset = ybridPlayerListener.offsets.last else {
            XCTFail(); return
        }
        XCTAssertTrue(liveOffsetRange_LostSign.contains(-lastOffset), "\(-lastOffset) not within \(liveOffsetRange_LostSign)")
        
    }
    
    func test06_YbridControl_WindToDate_BeforeLastFullHour_Advertisement() throws {
        try AudioPlayer.open(for: ybridStageSwr3Endpoint, listener: ybridPlayerListener,
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
        
                let date = lastFullHour(secondsBefore:15)
                ybridControl.wind(to:date)
                wait(ybridControl, type: ItemType.ADVERTISEMENT, maxSeconds: 4)
                sleep(4)

                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: maxWindResponseS)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
    }
    
    
    func test07_YbridControl_SkipBackwardNewsForwardMusic() throws {
        try AudioPlayer.open(for: ybridStageSwr3Endpoint, listener: ybridPlayerListener,
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
        
                ybridControl.skipBackward(ItemType.NEWS)
                wait(ybridControl, type: ItemType.NEWS, maxSeconds: 4)
                sleep(8)
  
                ybridControl.skipForward(ItemType.MUSIC)
                wait(ybridControl, type: ItemType.MUSIC, maxSeconds: 4)
                sleep(6)
                
                ybridControl.stop()
                wait(ybridControl, until: PlaybackState.stopped, maxSeconds: 2)
                
                semaphore?.signal()
               })
        _ = semaphore?.wait(timeout: .distantFuture)
    }
    
    func test08_YbridControl_SkipBackwardsItem_LastItemAgain() throws {
        try AudioPlayer.open(for: ybridStageSwr3Endpoint, listener: ybridPlayerListener,
               ybridControl: { [self] (ybridControl) in
                
                ybridControl.play()
                wait(ybridControl, until: PlaybackState.playing, maxSeconds: 10)
                sleep(2)
        
                ybridControl.skipBackward(nil)
                let type = ybridPlayerListener.metadatas.last?.current?.type
                XCTAssertNotNil(type)
                Logger.testing.notice("currently playing \(type ?? ItemType.UNKNOWN)")

                sleep(4)
  
                ybridControl.skipBackward(nil)
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
    
    private func shift( _ range:Range<TimeInterval>, by:TimeInterval ) -> Range<TimeInterval> {
        let shiftedRange = range.lowerBound+by ..< range.upperBound+by
        return shiftedRange
    }

    private func wait(_ control:YbridControl, shifted: TimeInterval, maxSeconds:Int) {
        let shiftedRange_LostSign = shift(liveOffsetRange_LostSign, by: -shifted)
        let took = wait(max: maxSeconds) {
            return isOffset(control.offsetToLiveS, shifted: shifted)
        }
        XCTAssertLessThanOrEqual(took, maxSeconds, "offset to live not \((-shiftedRange_LostSign.lowerBound).S) ..< \((-shiftedRange_LostSign.upperBound).S) within \(maxSeconds) s")
    }
    
    private func wait(_ control:YbridControl, type: ItemType, maxSeconds:Int) {

        let took = wait(max: maxSeconds) {
            return ybridPlayerListener.isItem(type)
        }
        XCTAssertLessThanOrEqual(took, maxSeconds, "item type is \(ybridPlayerListener.metadatas.last?.current?.type), not \(type)")
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
}

class TestYbridPlayerListener : AbstractAudioPlayerListener, YbridControlListener {
    
  
    
    func reset() {
        offsets.removeAll()
        errors.removeAll()
        metadatas.removeAll()
    }
    
    var metadatas:[Metadata] = []
    var offsets:[TimeInterval] = []
    var errors:[AudioPlayerError] = []
    
    var offsetChanges:Int { get {
        return offsets.count
    }}
    
    func isItem(_ type:ItemType) -> Bool {
        if let currentType = metadatas.last?.current?.type {
            return type == currentType
        }
        return false
    }
    
    
    func offsetToLiveChanged(_ offset:TimeInterval?) {
        guard let offset = offset else { XCTFail(); return }
        offsets.append(offset)
    }
    
    override func metadataChanged(_ metadata: Metadata) {
        metadatas.append(metadata)
    }

    override func error(_ severity: ErrorSeverity, _ exception: AudioPlayerError) {
        errors.append(exception)
    }
    

    
}
