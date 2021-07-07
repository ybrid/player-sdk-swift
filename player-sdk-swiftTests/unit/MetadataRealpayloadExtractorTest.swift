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
        func reset() {
            datas.removeAll()
            titles.removeAll()
        }
        
        var datas:[Data] = []
        func audiodataReady(_ data: Data) {
            datas.append(data)
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
        consumer.reset()
    }
    
    func testRealMetadata_1() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
        let input = try readDataFromFile("swr3recIncl1024MD_1")!
        extractor.portion(payload: input)
        XCTAssertEqual(consumer.datas.count, 220)
        extractor.flush()
        
        XCTAssertEqual(consumer.datas.count, 221)

        XCTAssertEqual(consumer.titles.count, 2)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Olivia Rodrigo - Good 4 U")}
        
        let mdIndicatorBytes = input.count / 1024 - 1
        XCTAssertEqual(input.count - mdIndicatorBytes - 32*16 - 13*16, consumer.datas.map { $0.count }.reduce(0, +) ) 

    }
    
    func testRealMetadata_2_WholePayload() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
        let input = try readDataFromFile("swr3recIncl1024MD_2")!
        extractor.portion(payload: input)
        extractor.flush()
        
        XCTAssertEqual(consumer.titles.count, 2)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Eric Clapton - Layla")}
        
        XCTAssertEqual(consumer.datas.count, 63)
        
        let mdIndicatorBytes = input.count / 1024 - 1
        XCTAssertEqual(mdIndicatorBytes, consumer.datas.count - 1)
        
        XCTAssertEqual(input.count - mdIndicatorBytes - 31*16 - 13*16, consumer.datas.map { $0.count }.reduce(0, +) )
    }
    
    func testRealMetadata_Sliced1000_ok() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
 
        let input = try readDataFromFile("swr3recIncl1024MD_2")!
        let chunkSize = 1000  // > 760 ok
        let slices = createChunks(forData: input, chunkSize: chunkSize)
        print("input of \(input.count) split into \(slices.count) of \(chunkSize)")

        for slice in slices {
           extractor.portion(payload: slice)
        }
        extractor.flush()
        
        XCTAssertEqual(consumer.titles.count, 2)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Eric Clapton - Layla")}
        XCTAssertEqual(consumer.datas.count, 63)
        
        let mdIndicatorBytes = input.count / 1024 - 1
        XCTAssertEqual(mdIndicatorBytes, consumer.datas.count - 1)
        
        XCTAssertEqual(input.count - mdIndicatorBytes - 31*16 - 13*16, consumer.datas.map { $0.count }.reduce(0, +) )
    }
    
    func testRealMetadata_Sliced1000_until1stMetadata_flush() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
 
        let input = try readDataFromFile("swr3recIncl1024MD_2")!
        let chunkSize = 1000  // > 760 ok
        let slices = createChunks(forData: input, chunkSize: chunkSize)
        print("input of \(input.count) split into \(slices.count) of \(chunkSize)")

        let firstSlices = slices[0 ..<  2]
        for slice in firstSlices {
            extractor.portion(payload: slice)
            print("slice has \(slice.description) bytes")
        }
        
        XCTAssertEqual(consumer.datas.count, 1)
        XCTAssertEqual(1024, consumer.datas.map { $0.count }.reduce(0, +))
        XCTAssertEqual(consumer.titles.count, 1)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Eric Clapton - Layla")}
        
        extractor.flush()
        XCTAssertEqual(consumer.datas.count, 2)
        
        let mdIndicatorBytes = 2000 / 1024
        XCTAssertEqual(mdIndicatorBytes, consumer.datas.count - 1)
        XCTAssertEqual(2000 - mdIndicatorBytes - 31*16, consumer.datas.map { $0.count }.reduce(0, +))
    }
    
   
    func testRealMetadata_Sliced500() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
 
        let input = try readDataFromFile("swr3recIncl1024MD_2")!
        let chunkSize = 500  // <= 760 error
        let slices = createChunks(forData: input, chunkSize: chunkSize)
        print("input of \(input.count) split into \(slices.count) of \(chunkSize)")
        
        for slice in slices {
            extractor.portion(payload: slice)
        }
        extractor.flush()
        
        XCTAssertEqual(consumer.titles.count, 2)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Eric Clapton - Layla")}
        XCTAssertEqual(consumer.datas.count, 63)
        
        let mdIndicatorBytes = input.count / 1024 - 1
        XCTAssertEqual(mdIndicatorBytes, consumer.datas.count - 1)
        
        XCTAssertEqual(input.count - mdIndicatorBytes - 31*16 - 13*16, consumer.datas.map { $0.count }.reduce(0, +) ) 
    }
    
    func testRealMetadata_Sliced500_FirstMd() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
 
        let input = try readDataFromFile("swr3recIncl1024MD_2")!
        let chunkSize = 500
        let slices = createChunks(forData: input, chunkSize: chunkSize)
        
        let firstSlices = slices[0 ..<  4]
        print("input of \(input.count) bytes, split into \(slices.count) of \(chunkSize) bytes, using \(firstSlices.count)")

        for slice in firstSlices {
            extractor.portion(payload: slice)
        }
        extractor.flush()

        
        XCTAssertEqual(consumer.titles.count, 1)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Eric Clapton - Layla")}
        
        XCTAssertEqual(consumer.datas.count, 2)
        
        let mdIndicatorBytes = 2000 / 1024
        XCTAssertEqual(mdIndicatorBytes, consumer.datas.count - 1)
        XCTAssertEqual(2000 - mdIndicatorBytes - 31*16, consumer.datas.map { $0.count }.reduce(0, +))

    }
    
    func testRealMetadata_Sliced500_FirstMdPlus() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
 
        let input = try readDataFromFile("swr3recIncl1024MD_2")!
        let chunkSize = 500
        let slices = createChunks(forData: input, chunkSize: chunkSize)
        
        let firstSlices = slices[0 ..<  5]
        print("input of \(input.count) bytes, split into \(slices.count) of \(chunkSize) bytes, using \(firstSlices.count)")

        for slice in firstSlices {
            extractor.portion(payload: slice)
        }
        extractor.flush()

        
        XCTAssertEqual(consumer.titles.count, 1)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Eric Clapton - Layla")}
        
        XCTAssertEqual(consumer.datas.count, 2)
        
        let mdIndicatorBytes = 2500 / 1024 - 1
        XCTAssertEqual(mdIndicatorBytes, consumer.datas.count - 1)
        XCTAssertEqual(2500 - mdIndicatorBytes - 31*16, consumer.datas.map { $0.count }.reduce(0, +))
    }
    
    func testRealMetadata_Sliced500_FirstMdPlusPlus() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
 
        let input = try readDataFromFile("swr3recIncl1024MD_2")!
        let chunkSize = 500
        let slices = createChunks(forData: input, chunkSize: chunkSize)
        
        let firstSlices = slices[0 ..<  6]
        print("input of \(input.count) bytes, split into \(slices.count) of \(chunkSize) bytes, using \(firstSlices.count)")

        for slice in firstSlices {
            extractor.portion(payload: slice)
        }
        extractor.flush()

        
        XCTAssertEqual(consumer.titles.count, 2)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Eric Clapton - Layla")}
        
        XCTAssertEqual(consumer.datas.count, 3)
        
        let mdIndicatorBytes = 3000 / 1024
        XCTAssertEqual(mdIndicatorBytes, consumer.datas.count - 1)
        XCTAssertEqual(3000 - mdIndicatorBytes - 31*16 - 13*16, consumer.datas.map { $0.count }.reduce(0, +))
    }
    
    func testRealMetadata_Sliced100() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
 
        let input = try readDataFromFile("swr3recIncl1024MD_2")!
        let chunkSize = 100
        let slices = createChunks(forData: input, chunkSize: chunkSize)
        print("input of \(input.count) split into \(slices.count) of \(chunkSize)")
        
        for slice in slices {
           extractor.portion(payload: slice)
        }
        extractor.flush()

        
        XCTAssertEqual(consumer.titles.count, 2)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Eric Clapton - Layla")}
        
        XCTAssertEqual(consumer.datas.count, 63)
        let mdIndicatorBytes = input.count / 1024 - 1
        XCTAssertEqual(mdIndicatorBytes, consumer.datas.count - 1)
        XCTAssertEqual(input.count - mdIndicatorBytes - 1*(31*16) - 1*(13*16), consumer.datas.map { $0.count }.reduce(0, +))
    }
    
    private func createChunks(forData: Data, chunkSize:Int) -> [Data] {

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
        
        for slice in slices {
           extractor.portion(payload: slice)
        }
        extractor.flush()
        
        XCTAssertEqual(consumer.titles.count, 2)
        consumer.titles.forEach{ XCTAssertEqual( $0, "Eric Clapton - Layla")}
        
        let mdIndicatorBytes = input.count / 1024 - 1
        XCTAssertEqual(input.count - mdIndicatorBytes - 1*(31*16) - 1*(13*16), consumer.datas.map { $0.count }.reduce(0, +))
    }
 
    
    private func createRandomChunks(forData: Data, _ range: ClosedRange<Int>) -> [Data] {

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
