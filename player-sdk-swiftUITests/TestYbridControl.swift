//
// TestYbridControl.swift
// player-sdk-swift
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
import YbridPlayerSDK
import XCTest

class TestYbridControl {
    
    let endpoint:MediaEndpoint
    
    let listener:YbridControlListener
    var ybrid:YbridControl?

    let poller = Poller()
    
    init(_ endpoint:MediaEndpoint, listener:YbridControlListener) {
        self.endpoint = endpoint
        self.listener = listener
    }
    
    func playing( action: @escaping (YbridControl, TestYbridControl?)->() ) {
        let semaphore = DispatchSemaphore(value: 0)
        do {
            try AudioPlayer.open(for: endpoint, listener: listener,
                 playbackControl: { (ctrl) in ctrl.close()
                    XCTFail("YbridControl expected, but was PlaybackControl")
                    semaphore.signal(); return },
                 ybridControl: { [self] (ybridControl) in
                    self.ybrid = ybridControl
                    
                    ybridControl.play()
                    poller.wait(ybridControl, until:PlaybackState.playing, maxSeconds:10)
                    
                    action(ybridControl, self)
                    
                    ybridControl.stop()
                    poller.wait(ybridControl, until:PlaybackState.stopped, maxSeconds:2)
                    ybridControl.close()
                    semaphore.signal()
                 })
        } catch {
            XCTFail("no player. Something went wrong");
            semaphore.signal(); return
        }
        _ = semaphore.wait(timeout: .distantFuture)
        self.ybrid = nil
    }
    
    func stopped( action: @escaping (YbridControl)->() ) {
        let semaphore = DispatchSemaphore(value: 0)
        do {
            try AudioPlayer.open(for: endpoint, listener: listener,
                 playbackControl: { (ctrl) in semaphore.signal()
                    XCTFail(); return },
                 ybridControl: { (ybridControl) in
                    
                    action(ybridControl)
                    
                    ybridControl.close()
                    semaphore.signal()
                 })
        } catch {
            XCTFail("no player. Something went wrong");
            semaphore.signal(); return
        }
        _ = semaphore.wait(timeout: .distantFuture)
    }
    
    // MARK: timeshift
    
    func windSynced(by:TimeInterval, maxWait:TimeInterval? = nil) -> (Trace) {
        let mySema = DispatchSemaphore(value: 0)
        let trace = Trace("wind by \(by.S)")
        guard let ybrid = ybrid else { return trace }
        ybrid.wind(by: by ) { (success) in
            self.timeshiftComplete(success, trace)
            mySema.signal()
        }
        if let maxWait = maxWait {
            _ = mySema.wait(timeout: .now() + maxWait)
        } else {
            _ = mySema.wait(timeout: .distantFuture)
        }
        return trace
    }
    
    func windSynced(to:Date?, maxWait:TimeInterval? = nil) -> (Trace) {
        
        let mySema = DispatchSemaphore(value: 0)
        let trace:Trace
        if let date = to {
            trace = Trace("wind to \(date)")
            guard let ybrid = ybrid else { return trace }
            ybrid.wind(to: date ) { (success) in
                self.timeshiftComplete(success, trace)
                mySema.signal()
            }
        } else {
            trace = Trace("wind live")
            guard let ybrid = ybrid else { return trace }
            ybrid.windToLive() { (success) in
                self.timeshiftComplete(success, trace)
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
    
    func skipSynced(_ count:Int, to type:ItemType? = nil, maxWait:TimeInterval? = nil) -> Trace {
        guard count == 1 || count == -1 else {
            Logger.testing.error("-- skip \(count) not supported")
            return Trace("denied skipping \(count) to \(String(describing: type))")
        }
        let mySema = DispatchSemaphore(value: 0)
        let trace:Trace
        if count == 1 {
            if let type = type {
                trace = Trace("skip forward to \(type)")
                guard let ybrid = ybrid else { return trace }
                ybrid.skipForward(type) { (success) in
                    self.timeshiftComplete(success, trace)
                    mySema.signal()
                }
            } else {
                trace = Trace("skip forward to item")
                guard let ybrid = ybrid else { return trace }
                ybrid.skipForward() { (success) in
                    self.timeshiftComplete(success, trace)
                    mySema.signal()
                }
        }} else {
            if let type = type {
                trace = Trace("skip backward to \(type)")
                guard let ybrid = ybrid else { return trace }
                ybrid.skipBackward(type) { (success) in
                    self.timeshiftComplete(success, trace)
                    mySema.signal()
                }
            } else {
                trace = Trace("skip backward to item")
                guard let ybrid = ybrid else { return trace }
                ybrid.skipBackward() { (success) in
                    self.timeshiftComplete(success, trace)
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

    
    private func timeshiftComplete(_ success:Bool,_ trace:Trace) {
       trace.complete(success)
       Logger.testing.notice( "***** audio complete ***** did \(success ? "":"not ")\(trace.name)")
       sleep(3)
    }
    
    
    // MARK: swap service
    
    func swapServiceSynced(to serviceId:String, maxWait:TimeInterval? = nil) -> (Trace) {
        let mySema = DispatchSemaphore(value: 0)
        let trace = Trace("swap to \(serviceId)")
        guard let ybrid = ybrid else { return trace }
        ybrid.swapService(to: serviceId) { (success) in
            self.swapServiceComplete(success, trace)
            mySema.signal()
        }
        if let maxWait = maxWait {
            _ = mySema.wait(timeout: .now() + maxWait)
        } else {
            _ = mySema.wait(timeout: .distantFuture)
        }
        return trace
    }


    private func swapServiceComplete(_ success:Bool,_ trace:Trace) {
       trace.complete(success)
       Logger.testing.notice( "***** audio complete ***** did \(success ? "":"not ")\(trace.name)")
       sleep(3)
    }

    // MARK: swa item
    
    func swapItemSynced(maxWait:TimeInterval? = nil) -> Trace {
        let mySema = DispatchSemaphore(value: 0)
        let trace = Trace("swap item")
        guard let ybrid = ybrid else { return trace }
        ybrid.swapItem() { (success) in
            self.swapItemComplete(success, trace)
            mySema.signal()
        }
        if let maxWait = maxWait {
            _ = mySema.wait(timeout: .now() + maxWait)
        } else {
            _ = mySema.wait(timeout: .distantFuture)
        }
        return trace
    }

    fileprivate func swapItemComplete(_ success:Bool,_ trace:Trace) {
       trace.complete(success)
       Logger.testing.notice( "***** audio complete ***** did \(success ? "":"not ")\(trace.name)")
       sleep(3)
    }

    
}
