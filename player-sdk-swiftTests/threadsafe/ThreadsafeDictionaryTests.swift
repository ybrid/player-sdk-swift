//
// ThreadsafeDictionaryTests.swift
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

class ThreadsafeDictionaryTests: XCTestCase {

    var dictionary = ThreadsafeDictionary<Int,TestInstance>(queueLabel: "io.ybrid.threadsafe.dictionary.testing")
    
    override func setUpWithError() throws {
        dictionary.removeAll()
    }
    
    class TestInstance {
        let id:Int
        init(_ listenerId: Int) {
            self.id = listenerId
        }
    }
  
    
    func testRegister()  {
        let listener = TestInstance(0)
        dictionary.put(id: listener.id, value: listener)
        XCTAssertEqual(1, dictionary.count)
    }

    func testUnregister()  {
        let listener = TestInstance(0)
        dictionary.remove(id: listener.id)
        XCTAssertEqual(0, dictionary.count)
    }

    func testRegisterUnregister()  {
        let listener = TestInstance(0)
        dictionary.put(id: listener.id, value: listener)
        XCTAssertEqual(1, dictionary.count)
        dictionary.remove(id: listener.id)
        XCTAssertEqual(0, dictionary.count)
    }

    func testRegisterRegister()  {
        let listener = TestInstance(0)
        dictionary.put(id: listener.id, value: listener)
        XCTAssertEqual(1, dictionary.count)
        dictionary.put(id: listener.id, value: listener)
        XCTAssertEqual(1, dictionary.count)
        dictionary.remove(id: listener.id)
        XCTAssertEqual(0, dictionary.count)
    }
    
    func testRegister1Register2()  {
        let listener1 = TestInstance(1)
        let listener2 = TestInstance(2)
        dictionary.put(id: listener1.id, value: listener1)
        XCTAssertEqual(1, dictionary.count)
        dictionary.put(id: listener2.id, value: listener2)
        XCTAssertEqual(2, dictionary.count)
        dictionary.remove(id: listener1.id)
        XCTAssertEqual(1, dictionary.count)
    }
    
    func testWildRegistrations() {
        var listeners:[TestInstance] = []
        let nListeners = 20
        for i in 1...nListeners {
            listeners.append(TestInstance(i))
        }
        wild((5...100)) { // one is registering each 5 to 100 ms
            let randomListener = listeners[Int.random(in: 0...nListeners-1)]
            self.dictionary.put(id: randomListener.id, value: randomListener)
        }
        wild(5...200) { // one is unregistering each 5 to 200 ms
            let randomListener = listeners[Int.random(in: 0...nListeners-1)]
            self.dictionary.remove(id: randomListener.id)
        }
        wild(500...500) { // report each 0.5 seconds
            print ("registered \(self.dictionary.count) instance")
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
