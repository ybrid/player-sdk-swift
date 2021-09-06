//
// YbridResponseTests.swift
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
@testable import YbridPlayerSDK

class YbridResponseTests : XCTestCase {

    let decoder = JSONDecoder()
    override func setUpWithError() throws {
        self.decoder.dateDecodingStrategy = JSONDecoder.DateDecodingStrategy.flexMillisIso8601
    }

    #if SWIFT_PACKAGE
        private func readJsonFromFile(_ filename:String) throws -> Data? {
            guard let res = Bundle.module.path(forResource: filename, ofType: "json") else {
                return nil
            }
            let url = NSURL.fileURL(withPath: res)
            return try Data(contentsOf: url)
        }
    #else
        private func readJsonFromFile(_ filename:String) throws -> Data? {
            let bundle = Bundle(for: type(of: self))
            if let url = bundle.url(forResource: filename, withExtension: "json")
            {
                let jsonData = try Data(contentsOf: url)
                return jsonData
            }
            return nil
        }
    #endif

    func testYbridV2DecodeJson_Standard() throws {
        guard let jsonData = try readJsonFromFile("ybridSessionCreated") else {
            XCTFail(); return
        }
        
        let ybrid = try decoder.decode(YbridSessionResponse.self, from: jsonData )
        XCTAssertNotNil(ybrid)
        print(ybrid)
        
        let timestamp = ybrid.__responseHeader.timestamp
        XCTAssertNotNil(timestamp)
        
        let currentItem = ybrid.__responseObject.metadata?.currentItem
        XCTAssertNotNil(currentItem)
        XCTAssertEqual("Air", currentItem?.artist)
        
        // not in info or session response
        XCTAssertNil(currentItem?.classifiedType)
    }
    
    
    func testYbridV2Response_DateWithoutMillis() throws {
        guard let jsonData = try readJsonFromFile("ybridResponseNoMilliseconds") else {
            XCTFail(); return
        }
        
        let ybrid = try decoder.decode(YbridResponse.self, from: jsonData )
        XCTAssertNotNil(ybrid)
        print(ybrid)
        let timestamp = ybrid.__responseHeader.timestamp
        XCTAssertNotNil(timestamp)
    }
    
    func testYbridV2Response_DateWithMillis() throws {
        guard let jsonData = try readJsonFromFile("ybridResponseMilliseconds") else {
            XCTFail(); return
        }
        
        let ybrid = try decoder.decode(YbridResponse.self, from: jsonData)
        XCTAssertNotNil(ybrid)
        print(ybrid)
        let timestamp = ybrid.__responseHeader.timestamp
        XCTAssertNotNil(timestamp)
    }
    
    
    
    func testYbridWindedResponse() throws {
        guard let jsonData = try readJsonFromFile("ybridWindBackResponse") else {
            XCTFail(); return
        }
        
        let ybrid = try decoder.decode(YbridWindResponse.self, from: jsonData)
        XCTAssertNotNil(ybrid)
        print(ybrid)
        
        let newType = ybrid.__responseObject.newCurrentItem.classifiedType
        XCTAssertNotNil(newType)
        XCTAssertEqual("MUSIC",newType)
    }
    
    func testYbridWindedToLiveResponse() throws {
        guard let jsonData = try readJsonFromFile("ybridWindToLiveResponse") else {
            XCTFail(); return
        }
        
        let ybrid = try decoder.decode(YbridWindResponse.self, from: jsonData)
        XCTAssertNotNil(ybrid)
        print(ybrid)
        
        let newType = ybrid.__responseObject.newCurrentItem.classifiedType
        XCTAssertNotNil(newType)
        XCTAssertEqual("MUSIC",newType)
    }
    
    
    func testYbridDateMillisTest() throws {
        guard let jsonData = try readJsonFromFile("ybridDateDecoding") else {
            XCTFail(); return
        }
        
        let ybrid = try decoder.decode(YbridTestDate.self, from: jsonData)
        XCTAssertNotNil(ybrid)
        
        print(ybrid)

        print(Formatter.iso8601withNanos.string(for: ybrid.timestamp0)!)
        print(Formatter.iso8601withNanos.string(for: ybrid.timestamp1)!)
        print(Formatter.iso8601withNanos.string(for: ybrid.timestamp2)!)
        print(Formatter.iso8601withNanos.string(for: ybrid.timestamp3)!)
        print(Formatter.iso8601withNanos.string(for: ybrid.timestamp4)!)
    }
    
    struct YbridTestDate: Codable {
        let timestamp0: Date
        let timestamp1: Date
        let timestamp2: Date
        let timestamp3: Date
        let timestamp4: Date
    }
    
    func testYbridDateNoMicrosTest() throws {
        guard let jsonData = try readJsonFromFile("ybridDateDecodingNanos") else {
            XCTFail(); return
        }
        
        let ybrid = try decoder.decode(YbridTestDate.self, from: jsonData)
        XCTAssertNotNil(ybrid)
        
        print(ybrid)

        print(Formatter.iso8601withNanos.string(for: ybrid.timestamp0)!)
        print(Formatter.iso8601withNanos.string(for: ybrid.timestamp1)!)
        print(Formatter.iso8601withNanos.string(for: ybrid.timestamp2)!)
        print(Formatter.iso8601withNanos.string(for: ybrid.timestamp3)!)
        print(Formatter.iso8601withNanos.string(for: ybrid.timestamp4)!)
    }
    
    // MARK: swap tests
    
    func testYbridSwapItemResponse() throws {
        guard let jsonData = try readJsonFromFile("ybridSwapItemResponse") else {
            XCTFail(); return
        }
        
        let ybrid = try decoder.decode(YbridSwapItemResponse.self, from: jsonData)
        XCTAssertNotNil(ybrid)
        print(ybrid)
    }
    
    func testYbridInfoResponse_Swaps() throws {
        guard let jsonData = try readJsonFromFile("ybridNewsResponse") else {
            XCTFail(); return
        }
        
        let ybrid = try decoder.decode(YbridSessionResponse.self, from: jsonData)
        XCTAssertNotNil(ybrid)
        print(ybrid)
        XCTAssertEqual(0,ybrid.__responseObject.swapInfo?.swapsLeft)
        
        let bouquet = ybrid.__responseObject.bouquet
        XCTAssertNotNil(bouquet)
        XCTAssertEqual(6, bouquet?.availableServices.count)
    }
    
    func testYbridInfoResponse_SwapService() throws {
        guard let jsonData = try readJsonFromFile("ybridSwapServiceResponse") else {
            XCTFail(); return
        }
        
        let ybrid = try decoder.decode(YbridSwapServiceResponse.self, from: jsonData)
        XCTAssertNotNil(ybrid)
        print(ybrid)
        let bouquet = ybrid.__responseObject.bouquet
        
        XCTAssertNotNil(bouquet)
        XCTAssertEqual(2, bouquet.availableServices.count)
    }
    
    func testYbridBitrateResponse() throws {
        guard let jsonData = try readJsonFromFile("ybridBitrateResponse") else {
            XCTFail(); return
        }
        
        let ybrid = try decoder.decode(YbridBitrateResponse.self, from: jsonData)
        XCTAssertNotNil(ybrid)
        print(ybrid)
        let rate = ybrid.__responseObject.maxBitRate
        
        XCTAssertNotNil(rate)
        XCTAssertEqual(rate, 32000)
    }
    
    // MARK: test productive responses
    
    func testYbridV2Swr3Json_Standard() throws {
        guard let jsonData = try readJsonFromFile("ybridSwr3InvalidResponse") else {
            XCTFail(); return
        }
        
        let ybrid = try decoder.decode(YbridSessionResponse.self, from: jsonData )
        XCTAssertNotNil(ybrid)
        print(ybrid)
        
        let timestamp = ybrid.__responseHeader.timestamp
        XCTAssertNotNil(timestamp)
        
        let currentItem = ybrid.__responseObject.metadata?.currentItem
        XCTAssertNotNil(currentItem)
        XCTAssertNotNil(currentItem?.artist)
        
        // not in info or session response
        XCTAssertNil(currentItem?.classifiedType)
    }
    
}

extension Formatter {
    static let iso8601withNanos: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSSXXXXX"
        return formatter
    }()
}


