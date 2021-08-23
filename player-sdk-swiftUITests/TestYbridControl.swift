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


class TestControl {
    
    var endpoint:MediaEndpoint
    let poller = Poller()
    
    var ctrlListener:TestAudioPlayerListener
    var ctrl:PlaybackControl?
    init(_ endpoint:MediaEndpoint, external:TestAudioPlayerListener? = nil) {
        self.endpoint = endpoint
        self.ctrlListener = external ?? TestAudioPlayerListener()
    }
    
    func playing(_ seconds:UInt32? = nil , action: ((PlaybackControl)->())? = nil) -> TestControl {
        let semaphore = DispatchSemaphore(value: 0)
        do {
            try AudioPlayer.open(for: endpoint, listener: ctrlListener,
                 control: { [self] (control) in
                    self.ctrl = control
                    control.play()
                    poller.wait(control, until:PlaybackState.playing, maxSeconds:10)
                    
                    action?(control)
                    if let forS = seconds {
                        sleep(forS)
                    }
                    
                    control.stop()
                    poller.wait(control, until:PlaybackState.stopped, maxSeconds:2)
                    control.close()
                    semaphore.signal()
                 })
        } catch {
            XCTFail("no player. Something went wrong");
            semaphore.signal(); ctrl = nil;
            return self
        }
        _ = semaphore.wait(timeout: .distantFuture)
        ctrl = nil
        return self
    }
    
    func stopped( action: @escaping (PlaybackControl)->() ) {
        let semaphore = DispatchSemaphore(value: 0)
        do {
            try AudioPlayer.open(for: endpoint, listener: ctrlListener,
                 control: { (control) in
                    self.ctrl = control
                    action(control)
                    
                    control.close()
                    semaphore.signal()
                 })
        } catch {
            XCTFail("no player. Something went wrong");
            semaphore.signal(); ctrl = nil
            return
        }
        _ = semaphore.wait(timeout: .distantFuture)
        ctrl = nil
    }
    
    func select(_ nextEndpoint:MediaEndpoint ) -> TestControl {
        
        self.endpoint = nextEndpoint
        
        return self
    }
    
    func checkErrors(expected:Int) -> TestControl {
        guard ctrlListener.errors.count == expected else {
            XCTFail("\(expected) errors expected, but were \(ctrlListener.errors.count)")
            ctrlListener.errors.forEach { (err) in
                let errMessage = err.localizedDescription
                Logger.testing.error("-- error is \(errMessage)")
            }
            return self
        }
        return self
    }
}


class TestYbridControl : TestControl {
    
    var listener:TestYbridPlayerListener { get {
        return ctrlListener as! TestYbridPlayerListener
    }}
    var ybrid:YbridControl? { get {
        return ctrl as? YbridControl
    }}

    let actionTraces = ActionsTrace()
    
    init(_ endpoint:MediaEndpoint, listener:TestYbridPlayerListener? = nil) {
        super.init(endpoint, external: listener ?? TestYbridPlayerListener())
    }

    
    func playing( action: @escaping (YbridControl)->() ) {
        let semaphore = DispatchSemaphore(value: 0)
        do {
            try AudioPlayer.open(for: endpoint, listener: listener,
                 playbackControl: { (ctrl) in ctrl.close()
                    XCTFail("YbridControl expected, but was PlaybackControl")
                    semaphore.signal(); return },
                 ybridControl: { [self] (ybridControl) in
                    self.ctrl = ybridControl
                    
                    ybridControl.play()
                    poller.wait(ybridControl, until:PlaybackState.playing, maxSeconds:10)
                    
                    action(ybridControl)
                    
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
        ctrl = nil
    }
    
    func stopped( action: @escaping (YbridControl)->() ) {
        let semaphore = DispatchSemaphore(value: 0)
        do {
            try AudioPlayer.open(for: endpoint, listener: listener,
                 playbackControl: { (ctrl) in ctrl.close()
                    XCTFail("YbridControl expected, but was PlaybackControl")
                    semaphore.signal(); return },
                 ybridControl: { [self] (ybridControl) in
                    self.ctrl = ybridControl
                    
                    action(ybridControl)
                    
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
        ctrl = nil
    }
    
    // checks
    override func checkErrors(expected:Int) -> TestYbridControl {
        return super.checkErrors(expected: expected) as! TestYbridControl
    }
    
    
    func checkAllActions(confirm:Int, areCompleted:Bool = true, withinS:TimeInterval) {
        actionTraces.check(confirm: confirm, mustBeCompleted: areCompleted, maxDuration: withinS)
    }
    
    // MARK: timeshift
    
    func windSynced(by:TimeInterval, maxWait:TimeInterval? = nil) {
        let mySema = DispatchSemaphore(value: 0)
        let trace = Trace("wind by \(by.S)")
        guard let ybrid = ybrid else { return }
        ybrid.wind(by: by ) { (success) in
            self.timeshiftComplete(success, trace)
            mySema.signal()
        }
        actionTraces.append(trace)
        
        if let maxWait = maxWait {
            _ = mySema.wait(timeout: .now() + maxWait)
        } else {
            _ = mySema.wait(timeout: .distantFuture)
        }
    }
    
    func windSynced(to:Date?, maxWait:TimeInterval? = nil) {
        
        let mySema = DispatchSemaphore(value: 0)
        let trace:Trace
        if let date = to {
            trace = Trace("wind to \(date)")
            guard let ybrid = ybrid else { return }
            ybrid.wind(to: date ) { (success) in
                self.timeshiftComplete(success, trace)
                mySema.signal()
            }
        } else {
            trace = Trace("wind live")
            guard let ybrid = ybrid else { return }
            ybrid.windToLive() { (success) in
                self.timeshiftComplete(success, trace)
                mySema.signal()
            }
        }
        actionTraces.append(trace)
        
        if let maxWait = maxWait {
            _ = mySema.wait(timeout: .now() + maxWait)
        } else {
            _ = mySema.wait(timeout: .distantFuture)
        }
    }
    
    func skipSynced(_ count:Int, to type:ItemType? = nil, maxWait:TimeInterval? = nil) {
        guard count == 1 || count == -1 else {
            Logger.testing.error("-- skip \(count) not supported")
            return
        }
        let mySema = DispatchSemaphore(value: 0)
        let trace:Trace
        if count == 1 {
            if let type = type {
                trace = Trace("skip forward to \(type)")
                guard let ybrid = ybrid else { return }
                ybrid.skipForward(type) { (success) in
                    self.timeshiftComplete(success, trace)
                    mySema.signal()
                }
            } else {
                trace = Trace("skip forward to item")
                guard let ybrid = ybrid else { return }
                ybrid.skipForward() { (success) in
                    self.timeshiftComplete(success, trace)
                    mySema.signal()
                }
        }} else {
            if let type = type {
                trace = Trace("skip backward to \(type)")
                guard let ybrid = ybrid else { return }
                ybrid.skipBackward(type) { (success) in
                    self.timeshiftComplete(success, trace)
                    mySema.signal()
                }
            } else {
                trace = Trace("skip backward to item")
                guard let ybrid = ybrid else { return }
                ybrid.skipBackward() { (success) in
                    self.timeshiftComplete(success, trace)
                    mySema.signal()
                }
        }}
        actionTraces.append(trace)
        
        if let maxWait = maxWait {
            _ = mySema.wait(timeout: .now() + maxWait)
        } else {
            _ = mySema.wait(timeout: .distantFuture)
        }
    }

    
    private func timeshiftComplete(_ success:Bool,_ trace:Trace) {
       trace.complete(success)
       Logger.testing.notice( "***** audio complete ***** did \(success ? "":"not ")\(trace.name)")
       sleep(3)
    }
    
    
    // MARK: swap service
    
    func swapServiceSynced(to serviceId:String, maxWait:TimeInterval? = nil) {
        let mySema = DispatchSemaphore(value: 0)
        let trace = Trace("swap to \(serviceId)")
        guard let ybrid = ybrid else { return }
        ybrid.swapService(to: serviceId) { (success) in
            self.swapServiceComplete(success, trace)
            mySema.signal()
        }
        actionTraces.append(trace)
        
        if let maxWait = maxWait {
            _ = mySema.wait(timeout: .now() + maxWait)
        } else {
            _ = mySema.wait(timeout: .distantFuture)
        }
    }


    private func swapServiceComplete(_ success:Bool,_ trace:Trace) {
       trace.complete(success)
       Logger.testing.notice( "***** audio complete ***** did \(success ? "":"not ")\(trace.name)")
       sleep(3)
    }

    // MARK: swap item
    
    func swapItemSynced(maxWait:TimeInterval? = nil) {
        let mySema = DispatchSemaphore(value: 0)
        let trace = Trace("swap item")
        guard let ybrid = ybrid else { return }
        ybrid.swapItem() { (success) in
            self.swapItemComplete(success, trace)
            mySema.signal()
        }
        actionTraces.append(trace)
        
        if let maxWait = maxWait {
            _ = mySema.wait(timeout: .now() + maxWait)
        } else {
            _ = mySema.wait(timeout: .distantFuture)
        }
    }

    fileprivate func swapItemComplete(_ success:Bool,_ trace:Trace) {
       trace.complete(success)
       Logger.testing.notice( "***** audio complete ***** did \(success ? "":"not ")\(trace.name)")
       sleep(3)
    }

    
}
