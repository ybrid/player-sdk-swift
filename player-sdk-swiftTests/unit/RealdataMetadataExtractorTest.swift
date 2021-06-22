//
// RealdataMetadataExtractorTest.swift
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

class RealdataMetadataExtractorTest: XCTestCase {
    
    private func readDataFromFile(_ filename:String) throws -> Data? {
        let bundle = Bundle(for: type(of: self))
        if let url = bundle.url(forResource: filename, withExtension: "mp3") {
            return try Data(contentsOf: url)
        }
        return nil
    }
    class TestMetadataListener : MetadataListener {
        var titles:[String] = []
        func metadataReady(_ metadata: AbstractMetadata) {
            if let title = metadata.displayTitle {
                titles.append(title)
            }
        }
    }
    var consumer = TestMetadataListener()
    override func setUpWithError() throws {  }
    override func tearDownWithError() throws {
        consumer.titles.removeAll()
    }
    
    func testRealMetadata() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 1024, listener: consumer)
        XCTAssert( extractor.intervalBytes == 1024 )
        let input = try readDataFromFile("swr3recIncl1024MD_kaputt2")
        let audioContent = extractor.handle(payload: input!)
        XCTAssertGreaterThan(audioContent.count,  0, "\(audioContent.count) audio bytes")
    }
    
}
