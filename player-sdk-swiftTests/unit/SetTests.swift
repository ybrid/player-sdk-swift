//
// SetTests.swift
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

class SetTests: XCTestCase {

    var mySet = MpegDecoder.ThreadsafeSet<UUID>("io.ybrid.decoder.cleanup.test")
    
    override func tearDownWithError() throws {
        print("\ncleaning \(mySet.count) entries")
        mySet.popAll { (id) in return }
    }
    
    func testInsert()  {
        let id = UUID()
        mySet.insert(id)
        XCTAssertEqual(1, mySet.count)
    }

    func testInsertPop()  {
        let id = UUID()
        mySet.insert(id)
        XCTAssertEqual(1, mySet.count)
        mySet.popAll { (id) in print(id); return }
        XCTAssertEqual(0, mySet.count)
    }

    func testInsertInsert()  {
        let id = UUID()
        mySet.insert(id)
        mySet.insert(id)
        XCTAssertEqual(1, mySet.count)
    }

    func testInsert1Insert2()  {
        mySet.insert(UUID())
        mySet.insert(UUID())
        XCTAssertEqual(2, mySet.count)
    }
    
    
    func testWildInsertsAndPops() {
        var stopIt = false
        wild(5...50, &stopIt) {
            for _ in 0...Int.random(in: 0...20) {
                print("+", terminator: "")
                self.mySet.insert(UUID())
            }
        }
        wild(5...50, &stopIt) {
            self.mySet.popAll { (id) in
                print("-", terminator: "")
                return
            }
        }
        wild(500...500, &stopIt) {
            print ("\nset has \(self.mySet.count) entries")
        }
        sleep(10)
        stopIt = true
        print("\nstopped")
        sleep(1)
    }

    
    fileprivate func wild(_ rangeMS:ClosedRange<Int>,_ endCondition: UnsafePointer<Bool>, act: @escaping () -> ()) {
        let rangeUS = rangeMS.lowerBound*1000...rangeMS.upperBound*1000
        DispatchQueue.global(qos: .background).async {
            while !endCondition.pointee {
                usleep(useconds_t(Int.random(in: rangeUS)))
                act()
            }
        }
    }
    
 
 
}
