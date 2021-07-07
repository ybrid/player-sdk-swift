//
// MetadataRealpayloadExtractorTest.swift
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

class MetadataRealpayloadExtractorTest: XCTestCase {
    
    private func readDataFromFile(_ filename:String) throws -> Data? {
        let bundle = Bundle(for: type(of: self))
        if let url = bundle.url(forResource: filename, withExtension: "mp3") {
            return try Data(contentsOf: url)
        }
        return nil
    }
    class TestMetadataListener : MetadataListener {
        func audiodataReady(_ data: Data) {
        }
        
        var titles:[String] = []
        func metadataReady(_ metadata: AbstractMetadata) {
            if let title = metadata.displayTitle {
                titles.append(title)
            }
        }
    }
    var consumer = TestMetadataListener()
    override func setUpWithError() throws {
        Logger.verbose = true
    }
    override func tearDownWithError() throws {
        consumer.titles.removeAll()
    }
    
    func testRealMetadata_1() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
        let input = try readDataFromFile("swr3recIncl1024MD_1")!
        let audioContent = extractor.handle(payload: input)
        XCTAssertGreaterThan(audioContent.count,  0, "\(audioContent.count) audio bytes")
        
        XCTAssertEqual(consumer.titles.count, 2)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Olivia Rodrigo - Good 4 U")}
    }
    
    func testRealMetadata_WholePayload() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
        let input = try readDataFromFile("swr3recIncl1024MD_2")!
        let audioContent = extractor.handle(payload: input)
        XCTAssertGreaterThan(audioContent.count,  0, "\(audioContent.count) audio bytes")
        
        XCTAssertEqual(consumer.titles.count, 2)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Eric Clapton - Layla")}
    }
    
    func testRealMetadata_Sliced1000_ok() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
 
        let input = try readDataFromFile("swr3recIncl1024MD_2")!
        let chunkSize = 1000  // > 760 ok
        let slices = createChunks(forData: input, chunkSize: chunkSize)
        print("input of \(input.count) split into \(slices.count) of \(chunkSize)")

        
        var bytes = 0
        for slice in slices {
           let audio = extractor.handle(payload: slice)
            bytes += audio.count
        }
        
        XCTAssertGreaterThan(bytes,  0, "\(bytes) audio bytes")
        
        XCTAssertEqual(consumer.titles.count, 2)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Eric Clapton - Layla")}
    }
    
    func testRealMetadata_Sliced1000_until1stMetadata() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
 
        let input = try readDataFromFile("swr3recIncl1024MD_2")!
        let chunkSize = 1000  // > 760 ok
        let slices = createChunks(forData: input, chunkSize: chunkSize)
        print("input of \(input.count) split into \(slices.count) of \(chunkSize)")

        let firstSlices = slices[0 ..<  2]
        var bytes = 0
        for slice in firstSlices {
           let audio = extractor.handle(payload: slice)
            bytes += audio.count
        }
        
        print("exctracted audio is \(bytes) bytes")
        XCTAssertGreaterThan(bytes,  0, "\(bytes) audio bytes")
        
        XCTAssertEqual(consumer.titles.count, 1)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Eric Clapton - Layla")}
    }
    
   
    func testRealMetadata_Sliced500() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
 
        let input = try readDataFromFile("swr3recIncl1024MD_2")!
        let chunkSize = 500  // <= 760 error
        let slices = createChunks(forData: input, chunkSize: chunkSize)
        print("input of \(input.count) split into \(slices.count) of \(chunkSize)")
        
        var bytes = 0
        for slice in slices {
           let audio = extractor.handle(payload: slice)
            bytes += audio.count
        }
        
        XCTAssertGreaterThan(bytes,  0, "\(bytes) audio bytes")
        
        XCTAssertEqual(consumer.titles.count, 2)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Eric Clapton - Layla")}
    }
    
    
    
    func testRealMetadata_Sliced500_FirstMd() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
 
        let input = try readDataFromFile("swr3recIncl1024MD_2")!
        let chunkSize = 500
        let slices = createChunks(forData: input, chunkSize: chunkSize)
        
        let firstSlices = slices[0 ..<  4]
        print("input of \(input.count) bytes, split into \(slices.count) of \(chunkSize) bytes, using \(firstSlices.count)")
        var bytes = 0
        for slice in firstSlices {
            let audio = extractor.handle(payload: slice)
            bytes += audio.count
        }
        
        print("exctracted audio is \(bytes) bytes")
        XCTAssertGreaterThan(bytes,  0, "\(bytes) audio bytes")
        
        XCTAssertEqual(consumer.titles.count, 1)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Eric Clapton - Layla")}
    }
    
    func testRealMetadata_Sliced100() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
 
        let input = try readDataFromFile("swr3recIncl1024MD_2")!
        let chunkSize = 100
        let slices = createChunks(forData: input, chunkSize: chunkSize)
        print("input of \(input.count) split into \(slices.count) of \(chunkSize)")
        
        var bytes = 0
        for slice in slices {
           let audio = extractor.handle(payload: slice)
            bytes += audio.count
        }
        
        XCTAssertGreaterThan(bytes,  0, "\(bytes) audio bytes")
        
        XCTAssertEqual(consumer.titles.count, 2)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Eric Clapton - Layla")}
    }
    
    func createChunks(forData: Data, chunkSize:Int) -> [Data] {

        var chunks:[Data] = []
        forData.withUnsafeBytes { (u8Ptr: UnsafePointer<UInt8>) in
            let mutRawPointer = UnsafeMutableRawPointer(mutating: u8Ptr)
            let totalSize = forData.count
            var offset = 0

            while offset < totalSize {

                let chunkSize = offset + chunkSize > totalSize ? totalSize - offset : chunkSize
                let chunk = Data(bytesNoCopy: mutRawPointer+offset, count: chunkSize, deallocator: Data.Deallocator.none)
                chunks.append(chunk)
                offset += chunkSize
            }
        }
        return chunks
    }
    
    func testRealMetadata_RandomSlices() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
 
        let input = try readDataFromFile("swr3recIncl1024MD_2")!
        let range:ClosedRange<Int> = 1...217
        let slices = createRandomChunks(forData: input, range)
        print("input of \(input.count) split into \(slices.count) slices of sizes \(range)")
        
        var bytes = 0
        for slice in slices {
           let audio = extractor.handle(payload: slice)
            bytes += audio.count
        }
        
        XCTAssertGreaterThan(bytes,  0, "\(bytes) audio bytes")
        
        XCTAssertEqual(consumer.titles.count, 2)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Eric Clapton - Layla")}
    }
 
    
    func createRandomChunks(forData: Data, _ range: ClosedRange<Int>) -> [Data] {

        var chunks:[Data] = []
        forData.withUnsafeBytes { (u8Ptr: UnsafePointer<UInt8>) in
            let mutRawPointer = UnsafeMutableRawPointer(mutating: u8Ptr)
            let totalSize = forData.count
            var offset = 0

            while offset < totalSize {
                var chunkSize  = Int.random(in: range)
                if offset + chunkSize > totalSize {
                    chunkSize = totalSize - offset
                }
                let chunk = Data(bytesNoCopy: mutRawPointer+offset, count: chunkSize, deallocator: Data.Deallocator.none)
                chunks.append(chunk)
                offset += chunkSize
            }
        }
        return chunks
    }
    
}
