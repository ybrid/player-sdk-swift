//
//  PackagesTests.swift
//  app-example-iosTests
//
//  Created by Florian Nowotny on 25.09.20.
//  Copyright © 2020 Florian Nowotny. All rights reserved.
//

import XCTest
import AVFoundation
@testable import YbridPlayerSDK

class DequeueTests: XCTestCase {
    
    var pkg1:String = "A"
    var pkg2:String = "B"
    
    override func setUpWithError() throws {

    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testEmptyTake() throws {
        let packets = MpegData.Dequeue<String>()
        XCTAssertEqual(0, packets.count)
        
        XCTAssertNil(packets.take())
        XCTAssertEqual(0, packets.count)
    }

    func testPutTakeTake() throws {
        let packets = MpegData.Dequeue<String>()
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
        let packets = MpegData.Dequeue<String>()
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
        let packets = MpegData.Dequeue<String>()
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
        let packets = MpegData.Dequeue<String>()
      
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
