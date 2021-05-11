//
// ContextMonitoringNetworkTests.swift
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
@testable import YbridPlayerSDK

// tests only thread safe regisgtration
class ContextMonitoringNetworkTests: XCTestCase {

    override func setUpWithError() throws {
        PlayerContext.networkMonitor.listeners.removeAll()
    }
    var regsisteredCount:Int {get{ return PlayerContext.networkMonitor.listeners.count}}

    
    class TestNetworkListener : NetworkListener {
        let id:Int
        var connectedCount = 0
        var unconnectedCount = 0
        init(_ listenerId: Int) {
            self.id = listenerId
        }
        func notifyNetworkChanged(_ connected: Bool) {
            if connected { connectedCount += 1 }
            else { unconnectedCount += 1}
        }
    }

    
    func testRegister()  {
        let listener = TestNetworkListener(0)
        PlayerContext.register(listener: listener)
        XCTAssertEqual(1, regsisteredCount)
    }

    func testUnregister()  {
        let listener = TestNetworkListener(0)
        PlayerContext.unregister(listener: listener)
        XCTAssertEqual(0, regsisteredCount)
    }

    func testRegisterUnregister()  {
        let listener = TestNetworkListener(0)
        PlayerContext.register(listener: listener)
        XCTAssertEqual(1, regsisteredCount)
        PlayerContext.unregister(listener: listener)
        XCTAssertEqual(0, regsisteredCount)
    }

    func testRegisterRegister()  {
        let listener = TestNetworkListener(0)
        PlayerContext.register(listener: listener)
        XCTAssertEqual(1, regsisteredCount)
        PlayerContext.register(listener: listener)
        XCTAssertEqual(1, regsisteredCount)
        PlayerContext.unregister(listener: listener)
        XCTAssertEqual(0, regsisteredCount)
    }
    
    func testRegister1Register2()  {
        let listener1 = TestNetworkListener(1)
        let listener2 = TestNetworkListener(2)
        PlayerContext.register(listener: listener1)
        XCTAssertEqual(1, regsisteredCount)
        PlayerContext.register(listener: listener2)
        XCTAssertEqual(2, regsisteredCount)
        PlayerContext.unregister(listener: listener1)
        XCTAssertEqual(1, regsisteredCount)
    }
    
    func testWildRegistrations() {
        var listeners:[TestNetworkListener] = []
        let nListeners = 20
        for i in 1...nListeners {
            listeners.append(TestNetworkListener(i))
        }
        wild((5...100)) { // one is registering each 5 to 100 ms
            let randomListener = listeners[Int.random(in: 0...nListeners-1)]
            PlayerContext.register(listener: randomListener)
        }
        wild(5...200) { // one is unregistering each 5 to 200 ms
            let randomListener = listeners[Int.random(in: 0...nListeners-1)]
            PlayerContext.unregister(listener: randomListener)
        }
        wild(500...500) { // report each 0.5 seconds
            print ("registered \(self.regsisteredCount) network listeners")
        }
        sleep(10)
    }
    
    fileprivate func wild(_ rangeMS:ClosedRange<Int>, act: @escaping () -> ()) {
        let rangeUS = rangeMS.lowerBound*1000...rangeMS.upperBound*1000
        DispatchQueue.global(qos: .background).async {
            while true {
                usleep(useconds_t(Int.random(in: rangeUS)))
                act()
            }
        }
    }
    

}
