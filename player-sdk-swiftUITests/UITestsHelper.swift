//
// UITestsHelper.swift
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

import Foundation
import XCTest
import YbridPlayerSDK

extension Logger {
    static let testing: Logger = Logger(category: "testing")
}

extension TimeInterval {
    var S:String {
        return String(format: "%.3f s", self)
    }

    var us:Int {
        return Int(self * 1_000_000)
    }
}






class TestAudioPlayerListener : AbstractAudioPlayerListener {

    func reset() {
        metadatas.removeAll()
        errors.removeAll()
    }
    
    var metadatas:[Metadata] = []
    override func metadataChanged(_ metadata: Metadata) {
        super.metadataChanged(metadata)
        Logger.testing.info("-- metadata changed, display title is \(metadata.displayTitle ?? "(nil)")")
        metadatas.append(metadata)
    }
    
    var errors:[AudioPlayerError] = []
    override func error(_ severity:ErrorSeverity, _ error: AudioPlayerError) {
        super.error(severity, error)
        errors.append(error)
    }

    override func playingSince(_ seconds: TimeInterval?) {
        if let duration = seconds {
            Logger.testing.notice("-- playing for \(duration.S) seconds ")
        } else {
            Logger.testing.notice("-- reset playing duration ")
        }
    }

    override func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {
        if let bufferLength = currentSeconds {
            Logger.testing.notice("-- currently buffered \(bufferLength.S) seconds of audio")
        }
    }
}


class AbstractAudioPlayerListener : AudioPlayerListener {

    func stateChanged(_ state: PlaybackState) {
        Logger.testing.notice("-- player is \(state)")
    }
    func error(_ severity:ErrorSeverity, _ exception: AudioPlayerError) {
        Logger.testing.notice("-- error \(severity): \(exception.localizedDescription)")
    }

    func metadataChanged(_ metadata: Metadata) {}
    func playingSince(_ seconds: TimeInterval?) {}

    func durationReadyToPlay(_ seconds: TimeInterval?) {
        if let duration = seconds {
            Logger.testing.notice("-- begin playing audio after \(duration.S) seconds ")
        } else {
            Logger.testing.notice("-- reset buffered until playing duration ")
        }
    }

    func durationConnected(_ seconds: TimeInterval?) {
        if let duration = seconds {
            Logger.testing.notice("-- recieved first data from url after \(duration.S) seconds ")
        } else {
            Logger.testing.notice("-- reset recieved first data duration ")
        }
    }

    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {}
}

class TimingListener : AudioPlayerListener {
    func cleanUp() {
        buffers.removeAll()
        errors.removeAll()
    }
    
    
    var buffers:[TimeInterval] = []
    func stateChanged(_ state: PlaybackState) {}
    func metadataChanged(_ metadata: Metadata) {}
    func playingSince(_ seconds: TimeInterval?) {}
    func durationReadyToPlay(_ seconds: TimeInterval?) {}
    func durationConnected(_ seconds: TimeInterval?) {}
    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {
        if let current = currentSeconds {
            buffers.append(current)
        }
    }
    
    var errors:[AudioPlayerError] = []
    func error(_ severity: ErrorSeverity, _ exception: AudioPlayerError) {
        errors.append(exception)
    }
}

class Poller {
    func wait(_ control:YbridControl, until:PlaybackState, maxSeconds:Int) {
        let took = wait(max: maxSeconds) {
            return control.state == until
        }
        XCTAssertLessThanOrEqual(took, maxSeconds, "not \(until) within \(maxSeconds) s")
    }

    func wait(max maxSeconds:Int, until:() -> (Bool)) -> Int {
        var seconds = 0
        while !until() && seconds <= maxSeconds {
            sleep(1)
            seconds += 1
        }
        XCTAssertTrue(until(), "condition not satisfied within \(maxSeconds) s")
        return seconds
    }
}

class TestYbridPlayerListener : AbstractAudioPlayerListener, YbridControlListener {
    
    let queue = DispatchQueue.init(label: "io.ybrid.tests.ui.listener")
    
    func reset() {
        queue.async { [self] in
            offsets.removeAll()
            errors.removeAll()
            metadatas.removeAll()
            services.removeAll()
        }
    }
    
    var metadatas:[Metadata] = []
    var offsets:[TimeInterval] = []
    var errors:[AudioPlayerError] = []
    var services:[[Service]] = []
    var swaps:[Int] = []
    
    
    // the latest recieved value for offset
    var offsetToLive:TimeInterval? { get {
        queue.sync {
            return offsets.last
        }
    }}
    
    // the latest value for swapsLeft
    var swapsLeft:Int? { get {
        queue.sync {
            return swaps.last
        }
    }}
    
    
    func isItem(_ type:ItemType) -> Bool {
        queue.sync {
            if let currentType = metadatas.last?.current?.type {
                return type == currentType
            }
            return false
        }
    }
    
    func offsetToLiveChanged(_ offset:TimeInterval?) {
        guard let offset = offset else { XCTFail(); return }
        Logger.testing.info("-- offset is \(offset.S)")
        queue.async {
            self.offsets.append(offset)
        }
    }

    func servicesChanged(_ services: [Service]) {
        Logger.testing.info("-- provided service ids are \(services.map{$0.identifier})")
        queue.async {
            self.services.append(services)
        }
    }
    
    func swapsChanged(_ swapsLeft: Int) {
        Logger.testing.info("-- swaps left \(swapsLeft)")
        queue.async {
            self.swaps.append(swapsLeft)
        }
    }
    
    override func metadataChanged(_ metadata: Metadata) {
        Logger.testing.notice("-- metadata: display title \(String(describing: metadata.displayTitle)), service \(String(describing: metadata.activeService?.identifier))")
        queue.async {
            self.metadatas.append(metadata)
        }
    }

    override func error(_ severity: ErrorSeverity, _ exception: AudioPlayerError) {
        super.error(severity, exception)
        queue.async {
            self.errors.append(exception)
        }
    }

}


class Trace {
    let name:String
    private var triggered:Date? = nil
    private var completed:Date? = nil
    var changed:Bool = false
    var valid:Bool { get {
        return triggered != nil && completed != nil
    }}
    var tookS:TimeInterval { get {
        guard valid else {
            return -1
        }
        return completed!.timeIntervalSince(triggered!)
    }}
    init(_ name:String) {
        self.name = name
        self.triggered = Date()
    }
    func complete(_ changed:Bool) {
        self.completed = Date()
        self.changed = changed
    }
}
class ActionsTrace {
    private var actions:[Trace] = []
    
    init() {}
    func reset() { actions.removeAll() }
    func append(_ trace:Trace) { actions.append(trace) }
    func newTrace(_ name:String) -> Trace {
        let trace = Trace(name)
        actions.append(trace)
        return trace
    }
    
    func checkTraces(expectedActions:Int) -> [(String,TimeInterval)] {
          
        guard actions.count == expectedActions else {
            XCTFail("expecting \(expectedActions) completed actions, but were \(actions.count)")
            return []
        }
        
        let actionsTook:[(String,TimeInterval)] = actions.filter{
             return $0.valid
        }.map{
            let actionTookS = $0.tookS
            Logger.testing.debug("\($0.changed ? "" : "not ")\($0.name) took \(actionTookS.S)")
            return ($0.name,actionTookS)
        }
        return actionsTook
    }

    func check(expectedActions:Int, maxDuration:TimeInterval) {
          
        XCTAssertEqual(actions.count,expectedActions, "expecting \(expectedActions) completed actions, but were \(actions.count)")
        
        actions.filter{
             return $0.valid
        }.forEach{
            Logger.testing.debug("\($0.changed ? "" : "not ")\($0.name) took \($0.tookS.S)")
            XCTAssertLessThan($0.tookS, maxDuration, "\($0.name) should take less than \(maxDuration.S), took \($0.tookS.S)")
        }
    }

}
