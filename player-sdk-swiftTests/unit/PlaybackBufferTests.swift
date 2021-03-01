//
// ChunkedCacheTests.swift
// app-example-ios
//
// Copyright (c) 2020 nacamar GmbH - Ybrid®, a Hybrid Dynamic Live Audio Technology
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

class PlaybackBufferTests: XCTestCase {

    class A {
        let packets = PlaybackBuffer.ThreadsafeDequeue<String>()
      
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
                print ("took \((self.packets.take() ?? "(nil)"))")
            }
        }
        
        func count() {
            DispatchQueue.global(qos: .background).async {
                usleep(useconds_t(Int.random(in: 100...1000)))
                print ("count \((self.packets.count))")
            }
        }
    }
    func testPutTakeThreadsafety() throws {
        let a = A()
        print("--------")
        var put = 0
        var take = 0
        var cnt = 0
        for _ in 1...2000 {
            DispatchQueue.global(qos: .default).async {
                usleep(useconds_t(Int.random(in: 100...1000)))
                a.put()
                put += 1
            }
            DispatchQueue.global(qos: .default).async {
                usleep(useconds_t(Int.random(in: 120...1200)))
                a.take()
                take += 1
            }
            DispatchQueue.global(qos: .default).async {
                usleep(useconds_t(Int.random(in: 10...1500)))
                a.count()
                cnt += 1
            }
        }
        Thread.sleep(forTimeInterval: 6.0)
        print("--------")
        print("put \(put), take \(take), cnt \(cnt)")
        print("--------")
    }
    

}
