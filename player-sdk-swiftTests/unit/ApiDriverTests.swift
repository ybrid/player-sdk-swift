//
// ApiDriverTests.swift
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

class ApiDriverTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    
    //   {"__responseHeader":{"responseVersion":"v2","statusCode":200,"success":true,"supportedVersions":["v1","v2"],"timestamp":"2021-04-13T08:29:35.815Z"}}
    
    
    func testApiVersion_YbridDemo() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://stagecast.ybrid.io/adaptive-demo")
        let driver = ApiDriver(endpoint)
        let version = driver.getVersion()

        XCTAssertEqual(ApiVersion.ybridV2, version)
    }

    func testApiVersion_Swr3() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://stagecast.ybrid.io/swr3/mp3/mid")
        let driver = ApiDriver(endpoint)
        let version = driver.getVersion()

        XCTAssertEqual(ApiVersion.ybridV2, version)
    }
    
    func testApiVersion_Hr2() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://hr-hr2-live.cast.addradio.de/hr/hr2/live/mp3/128/stream.mp3")
        let driver = ApiDriver(endpoint)
        let version = driver.getVersion()

        XCTAssertEqual(ApiVersion.icy, version)
    }
}
