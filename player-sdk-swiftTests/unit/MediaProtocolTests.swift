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

class MediaProtocolTests: XCTestCase {
    
    let factory = MediaControlFactory()
    
    func testFactoryGetVersion_YbridDemo() throws {
        let version = try factory.getVersion("https://stagecast.ybrid.io/adaptive-demo")
        XCTAssertEqual(MediaProtocol.ybridV2, version)
    }
    
    func testFactoryGetVersion_Swr3() throws {
        let version = try factory.getVersion("https://stagecast.ybrid.io/swr3/mp3/mid")
        XCTAssertEqual(MediaProtocol.ybridV2, version)
    }
    
    func testFactoryGetVersion_Swr3WrongUrl() throws {
        let version = try factory.getVersion("https://stagecast.ybrid.io/swr3/mp3")
        XCTAssertEqual(MediaProtocol.icy, version)
    }
    
    func testFactoryGetVersion_UrlNotFound() throws {
        let version = try factory.getVersion("https://stagecast.ybrid.io/gibtsNicht")
        XCTAssertEqual(MediaProtocol.icy, version)
    }
    
    func testFactoryGetVersion_Hr2() throws {
        let version = try factory.getVersion("https://hr-hr2-live.cast.addradio.de/hr/hr2/live/mp3/128/stream.mp3")
        XCTAssertEqual(MediaProtocol.icy, version)
    }
    
    func testFactoryGetVersion_BadUrl() throws {
        do {
            _ = try factory.getVersion("no url")
        } catch {
            XCTAssertTrue(error is ApiError)
            return
        }
        XCTFail()
    }
    
    
    func testFactoryGetVersion_OnDemand() throws {
        let version = try factory.getVersion("https://github.com/ybrid/test-files/blob/main/mpeg-audio/music/organ.mp3?raw=true")
        XCTAssertEqual(MediaProtocol.icy, version)
    }
    
    func testDriver_YbridDemo_Connect_Disconnect() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://stagecast.ybrid.io/adaptive-demo")
        let session = endpoint.createSession()
        XCTAssertNotNil(session, "expected a session")

        guard let controller = session.mediaControl else {
            XCTFail("expected a controller"); return
        }
        XCTAssertEqual(MediaProtocol.ybridV2, controller.mediaProtocol)
        XCTAssertTrue(controller.connected)
        XCTAssertNotNil(controller.playbackUri)
        XCTAssertTrue(controller.playbackUri.starts(with: "icyx"))
        XCTAssertTrue(controller.playbackUri.contains("edge"))
      
        controller.disconnect()
        XCTAssertFalse(controller.connected)
    }

    func testDriver_Swr3_Connect_Connect() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://stagecast.ybrid.io/swr3/mp3/mid")
        let session = endpoint.createSession()
        XCTAssertNotNil(session, "expected a session")
        guard let driver = session.mediaControl else {
            XCTFail(); return
        }
        XCTAssertEqual(MediaProtocol.ybridV2, driver.mediaProtocol)
        XCTAssertTrue(driver.connected)

        var playbackUri = driver.playbackUri
        XCTAssertTrue(playbackUri.starts(with: "icyx"))
        XCTAssertTrue(playbackUri.contains("edge"))
        
        try driver.connect()
        XCTAssertTrue(driver.connected)
        playbackUri = driver.playbackUri
        XCTAssertTrue(playbackUri.starts(with: "icyx"))
        XCTAssertTrue(playbackUri.contains("edge"))
    }
    
    func testDriver_Swr3WrongUrl_Connect() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://stagecast.ybrid.io/swr3/mp3")
        let session = endpoint.createSession()
        XCTAssertNotNil(session, "expected a session")
        XCTAssertNotNil(session.mediaControl)
        
        XCTAssertEqual(session.playbackUri, endpoint.uri)
    }
    
    
    func testDriver_Hr2() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://hr-hr2-live.cast.addradio.de/hr/hr2/live/mp3/128/stream.mp3")
        guard let driver = endpoint.createSession().mediaControl else {
            XCTFail(); return
        }
        XCTAssertEqual(MediaProtocol.icy, driver.mediaProtocol)
        XCTAssertEqual(endpoint.uri, driver.playbackUri)
        XCTAssertTrue(driver.connected)
    }
    
    func testDriver_EgoFM() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://egofm-live.cast.addradio.de/egofm/live/mp3/high/stream.mp3")
        guard let driver = endpoint.createSession().mediaControl else {
            XCTFail(); return
        }
        XCTAssertEqual(MediaProtocol.icy, driver.mediaProtocol)
        XCTAssertEqual(endpoint.uri, driver.playbackUri)
        XCTAssertTrue(driver.connected)
    }
    
    func testDriver_DlfOpus() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")
        guard let driver = endpoint.createSession().mediaControl else {
            XCTFail(); return
        }
        XCTAssertEqual(MediaProtocol.icy, driver.mediaProtocol)
        XCTAssertEqual(endpoint.uri, driver.playbackUri)
        XCTAssertTrue(driver.connected)
    }
    
    func testDriver_OnDemandSound() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://github.com/ybrid/test-files/blob/main/mpeg-audio/music/organ.mp3?raw=true")
        guard let driver = endpoint.createSession().mediaControl else {
            XCTFail(); return
        }
        XCTAssertEqual(MediaProtocol.icy, driver.mediaProtocol)
        XCTAssertEqual(endpoint.uri, driver.playbackUri)
        XCTAssertTrue(driver.connected)
    }
    
    
    
}
