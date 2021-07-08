//
// YbridV1ResponseTests.swift
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

class YbridV1ResponseTests: XCTestCase {

    let decoder = JSONDecoder()
    override func setUpWithError() throws {
        self.decoder.dateDecodingStrategy = JSONDecoder.DateDecodingStrategy.flexMillisIso8601
    }

    private func readJsonFromFile(_ filename:String) throws -> Data? {
        let bundle = Bundle(for: type(of: self))
        if let url = bundle.url(forResource: filename, withExtension: "json")
        {
            let jsonData = try Data(contentsOf: url)
            return jsonData
        }
        return nil
    }

    func testShowMetaResponse() throws {
        guard let jsonData = try readJsonFromFile("ybridStreamUrlMetadata") else {
            XCTFail(); return
        }
        
        let showMeta = try decoder.decode(YbridShowMeta.self, from: jsonData)
        XCTAssertNotNil(showMeta)
        print(showMeta)

        let millisToNext = showMeta.timeToNextItemMillis
        XCTAssertNotNil(millisToNext)
        XCTAssertEqual(millisToNext, 78144)
    }
    
    func testShowMetaResponse2() throws {
        guard let jsonData = try readJsonFromFile("ybridStreamUrlMetadata2") else {
            XCTFail(); return
        }
        
        let showMeta = try decoder.decode(YbridShowMeta.self, from: jsonData)
        XCTAssertNotNil(showMeta)
        print(showMeta)

        
        let millis = showMeta.timeToNextItemMillis
        XCTAssertNotNil(millis)
        XCTAssertEqual(millis, 247248)
    }
    
    func testShowMetaResponseSwr3() throws {
        guard let jsonData = try readJsonFromFile("ybridStreamUrlMetadataSwr3") else {
            XCTFail(); return
        }
        
        let showMeta = try decoder.decode(YbridShowMeta.self, from: jsonData)
        XCTAssertNotNil(showMeta)
        print(showMeta)

        
        let millis = showMeta.timeToNextItemMillis
        XCTAssertNotNil(millis)
        XCTAssertEqual(millis, 100932)
        XCTAssertEqual(showMeta.currentBitRate, 128000)

        XCTAssertNotEqual(showMeta.currentItem.type, ItemType.UNKNOWN.rawValue)
    }
}
