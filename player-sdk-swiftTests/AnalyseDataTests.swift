//
// AnalyseDataTests.swift
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

import XCTest
@testable import YbridPlayerSDK

class AnalyseDataTests: XCTestCase {

    func test_Swr3_RecordData() throws {
        let semaphore = DispatchSemaphore(value: 0)
        try AudioPlayer.open(for: ybridSwr3Endpoint, listener: nil) { (control) in
            control.play()
            sleep(6)
            control.stop()
            sleep(2)
            semaphore.signal() }
        _ = semaphore.wait(timeout: .distantFuture)
    }
    
    func test_Recorder() throws {
    
        let rec = Recorder1(recordingName: "rec1")
        rec.clear(recordingName: "rec1")
        rec.start()
        
        
        var input:Data = Data()
        let content: [UInt8] = [1,2,3,4]
        input.append(contentsOf: content)
        
        rec.add(input)
        rec.add(input)
        rec.stop()
    }
    
}


public class Recorder1 {

    var fileUrl: URL?
    private var outputStream: OutputStream?

    var mediadata:Data = Data()
    
    init(recordingName: String) {
        self.fileUrl = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        .appendingPathComponent(recordingName)
        print("recording to \(fileUrl?.absoluteString)")
    }

    func start() {
        if let file = fileUrl {
            outputStream = OutputStream(url: file, append: true)
            outputStream!.open()
        }
    }

    
    func add(_ data:Data) {
        if let ostream = outputStream {
            _ = try! data.withUnsafeBytes { (body:UnsafeRawBufferPointer) throws in
                if let unsafeBytes = body.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                    ostream.write(unsafeBytes, maxLength: data.count)
                }
            }
        }
        
        mediadata.append(data)
    }
    
    func stop() {
        if let file = fileUrl {
            print("\(mediadata.count) bytes recorded to \(file.absoluteString)")
            outputStream?.close()
        }
    }
    
    func clear(recordingName: String) {
        if let file = fileUrl {
            do {
                try FileManager.default.removeItem(at: file)
                print("\(file) deleted")
            } catch {
                print("could not delete \(file), Error: \(error)")
            }
            self.fileUrl = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent(recordingName)
            print("recording to \(file.absoluteString)")
        }
    }
}

