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
    
    var pkg1:String = "A"
    var pkg2:String = "B"
    
    override func setUpWithError() throws {
        
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testEmptyTake() throws {
        let packets = ThreadsafeDequeue<String>()
        XCTAssertEqual(0, packets.count)
        
        XCTAssertNil(packets.take())
        XCTAssertEqual(0, packets.count)
    }
    
    func testPutTakeTake() throws {
        let packets = ThreadsafeDequeue<String>()
        XCTAssertEqual(0, packets.count)
        packets.put(pkg1)
        XCTAssertEqual(1, packets.count)
        
        let next = packets.take()
        XCTAssertNotNil(next)
        XCTAssertEqual("A", next)
        XCTAssertEqual(0, packets.count)
        
        XCTAssertNil(packets.take())
    }
    
    func testPutPutTakeTake() throws {
        let packets = ThreadsafeDequeue<String>()
        packets.put(pkg1)
        packets.put(pkg2)
        XCTAssertEqual(2, packets.count)
        
        let next = packets.take()
        XCTAssertNotNil(next)
        XCTAssertEqual("A", next)
        XCTAssertEqual(1, packets.count)
        XCTAssertEqual("B", packets.take())
    }
    
    func testPutTakePutTake() throws {
        let packets = ThreadsafeDequeue<String>()
        packets.put(pkg1)
        XCTAssertEqual(1, packets.count)
        
        let next = packets.take()
        XCTAssertNotNil(next)
        XCTAssertEqual("A", next)
        
        packets.put(pkg2)
        XCTAssertEqual(1, packets.count)
        XCTAssertEqual("B", packets.take())
    }
    
    class A {
        let packets = ThreadsafeDequeue<String>()
        
        func put() {
            DispatchQueue.global(qos: .background).async {
                usleep(useconds_t(Int.random(in: 100...1000)))
                let char = String(UnicodeScalar(UInt8.random(in: 65...90))) // A bis Z
                print ("putting \(char)")
                self.packets.put(char)
            }
        }
        
        func take() {
            DispatchQueue.global(qos: .background).async {
                usleep(useconds_t(Int.random(in: 100...1000)))
                print ("took \((self.packets.take() ?? "nil"))")
            }
        }
    }
    func testPutTakeWow() throws {
        let a = A()
        print("--------")
        for _ in 0...1000 {
            // Single actions
            DispatchQueue.global(qos: .background).async {
                usleep(useconds_t(Int.random(in: 100...1000)))
                a.put()
            }
            DispatchQueue.global(qos: .default).async {
                usleep(useconds_t(Int.random(in: 100...1000)))
                a.take()
            }
        }
        Thread.sleep(forTimeInterval: 5.0)
        print("--------")
    }
    
    
}

