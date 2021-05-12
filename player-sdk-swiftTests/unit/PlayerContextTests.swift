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

// see also ThreadsafeDictionaryTests
class PlayerContextTests: XCTestCase {

    override func setUpWithError() throws {
        PlayerContext.networkMonitor.listeners.removeAll()
        PlayerContext.sharedMemoryMonitor.listeners.removeAll()
    }
    
    // MARK: testing network listener registration
    
    var networkListenersCount:Int {get{ return PlayerContext.networkMonitor.listeners.count}}
    class TestNetworkListener : NetworkListener {
        let id:Int
        init(_ listenerId: Int) {
            self.id = listenerId
        }
        func notifyNetworkChanged(_ connected: Bool) {
        }
    }

    
    func testNetworkMonitoring_Unregister()  {
        let listener = TestNetworkListener(0)
        PlayerContext.unregister(listener: listener)
        XCTAssertEqual(0, networkListenersCount)
    }

    func testNetworkMonitoring_RegisterUnregister()  {
        let listener = TestNetworkListener(0)
        PlayerContext.register(listener: listener)
        XCTAssertEqual(1, networkListenersCount)
        PlayerContext.unregister(listener: listener)
        XCTAssertEqual(0, networkListenersCount)
    }

    func testNetworkMonitoring_RegisterRegister()  {
        let listener = TestNetworkListener(0)
        PlayerContext.register(listener: listener)
        XCTAssertEqual(1, networkListenersCount)
        PlayerContext.register(listener: listener)
        XCTAssertEqual(1, networkListenersCount)
        PlayerContext.unregister(listener: listener)
        XCTAssertEqual(0, networkListenersCount)
    }
    
    func testNetworkMonitoring_Register1Register2()  {
        let listener1 = TestNetworkListener(1)
        let listener2 = TestNetworkListener(2)
        PlayerContext.register(listener: listener1)
        XCTAssertEqual(1, networkListenersCount)
        PlayerContext.register(listener: listener2)
        XCTAssertEqual(2, networkListenersCount)
        PlayerContext.unregister(listener: listener1)
        XCTAssertEqual(1, networkListenersCount)
    }
    
    // MARK: testing memory listener registration
    
    var memoryListenerCount:Int {get{ return PlayerContext.sharedMemoryMonitor.listeners.count}}
    class TestMemoryListener : MemoryListener {
        let id:Int
        init(_ listenerId: Int) {
            self.id = listenerId
        }
        func notifyExceedsMemoryLimit() {
        }
    }

    func testMemoryMonitoring_Unregister()  {
        let listener = TestMemoryListener(0)
        PlayerContext.unregisterMemoryListener(listener: listener)
        XCTAssertEqual(0, memoryListenerCount)
    }
    
    
    func testMemoryMonitoring_RegisterUnregister()  {
        let listener = TestMemoryListener(0)
        PlayerContext.registerMemoryListener(listener: listener)
        XCTAssertEqual(1, memoryListenerCount)
        PlayerContext.unregisterMemoryListener(listener: listener)
        XCTAssertEqual(0, memoryListenerCount)
    }

    func testMemoryMonitoring_RegisterRegister()  {
        let listener = TestMemoryListener(0)
        PlayerContext.registerMemoryListener(listener: listener)
        XCTAssertEqual(1, memoryListenerCount)
        PlayerContext.registerMemoryListener(listener: listener)
        XCTAssertEqual(1, memoryListenerCount)
        PlayerContext.unregisterMemoryListener(listener: listener)
        XCTAssertEqual(0, memoryListenerCount)
    }
    
    func testMemoryMonitoring_Register1Register2()  {
        let listener1 = TestMemoryListener(1)
        let listener2 = TestMemoryListener(2)
        PlayerContext.registerMemoryListener(listener: listener1)
        XCTAssertEqual(1, memoryListenerCount)
        PlayerContext.registerMemoryListener(listener: listener2)
        XCTAssertEqual(2, memoryListenerCount)
        PlayerContext.unregisterMemoryListener(listener: listener1)
        XCTAssertEqual(1, memoryListenerCount)
    }

}
