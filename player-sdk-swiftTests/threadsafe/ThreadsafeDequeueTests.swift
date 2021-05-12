//
// ThreadsafeDequeueTests.swift
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
import AVFoundation
@testable import YbridPlayerSDK

class ThreadsafeDequeueTests: XCTestCase {
    
    var items = ThreadsafeDequeue<String>(
        DispatchQueue(label: "io.ybrid.threadsafe.dequeue.tests", qos: PlayerContext.processingPriority)
    )

    override func tearDownWithError() throws {
        items.clear()
    }
    
    func testEmptyPop() throws {
        XCTAssertEqual(0, items.count)
        
        XCTAssertNil(items.pop())
        XCTAssertEqual(0, items.count)
    }
    
    func testPutPopPop() throws {
        XCTAssertEqual(0, items.count)
        items.put("A")
        XCTAssertEqual(1, items.count)
        
        let next = items.pop()
        XCTAssertNotNil(next)
        XCTAssertEqual("A", next)
        XCTAssertEqual(0, items.count)
        
        XCTAssertNil(items.pop())
    }
    
    func testPutPutPopPop() throws {
        items.put("A")
        items.put("B")
        XCTAssertEqual(2, items.count)
        
        let next = items.pop()
        XCTAssertNotNil(next)
        XCTAssertEqual("A", next)
        XCTAssertEqual(1, items.count)
        XCTAssertEqual("B", items.pop())
    }
    
    
    func testPutPutSamePopPop() throws {
        items.put("A")
        items.put("A")
        XCTAssertEqual(2, items.count)
        
        let next = items.pop()
        XCTAssertNotNil(next)
        XCTAssertEqual("A", next)
        XCTAssertEqual(1, items.count)
        XCTAssertEqual("A", items.pop())
    }
    
    func testPutPopPutPop() throws {
        items.put("A")
        XCTAssertEqual(1, items.count)
        
        let next = items.pop()
        XCTAssertNotNil(next)
        XCTAssertEqual("A", next)
        
        items.put("B")
        XCTAssertEqual(1, items.count)
        XCTAssertEqual("B", items.pop())
    }
    
    func testPutPopWild() throws {
        wild(100...1000) {
            let char = String(UnicodeScalar(UInt8.random(in: 65...90))) // from A to Z
            print ("putting \(char)")
            self.items.put(char)
        }
        wild(100...1000) {
            print ("taking \((self.items.pop() ?? "nil"))")
        }
        
        wild( 10...1500) {
            print ("size is \((self.items.count))")
        }
        
        Thread.sleep(forTimeInterval: 5.0)
    }
    
    private func wild(_ rangeUS:ClosedRange<Int>, act: @escaping () -> ()) {
        DispatchQueue.global(qos: .background).async {
            while true {
                usleep(useconds_t(Int.random(in: rangeUS)))
                act()
            }
        }
    }
    
}

