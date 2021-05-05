//
// SessionTests.swift
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

class MediaSessionTests: XCTestCase {

    let listener = MediaListener()
    override func setUpWithError() throws {
        listener.errors.removeAll()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    
    func testSession_YbridDemo() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://stagecast.ybrid.io/adaptive-demo")
        guard let session = endpoint.open(listener: listener) else {
            XCTFail("session expected"); return
        }
        let playbackUri = session.playbackUri
        XCTAssertTrue(playbackUri.starts(with: "icyx"))
        XCTAssertTrue(playbackUri.contains("edge"))
        guard let metadata = session.fetchMetadataSync() else {
            XCTFail("ybrid metadata expected"); return
        }
        print("running \(metadata.displayTitle ?? "(nil)")")
        XCTAssertNotNil(metadata)
        XCTAssertEqual(0, listener.errors.count)
        session.close()
    }

    func testSession_YbridSwr3() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://stagecast.ybrid.io/swr3/mp3/mid")
        guard let session = endpoint.open(listener: listener) else {
            XCTFail("session expected"); return
        }
        let playbackUri = session.playbackUri
        XCTAssertTrue(playbackUri.starts(with: "icyx"))
        XCTAssertTrue(playbackUri.contains("edge"))
        guard let metadata = session.fetchMetadataSync() else {
            XCTFail("ybrid metadata expected"); return
        }
        print("running \(metadata.displayTitle ?? "(nil")")
        XCTAssertEqual(0, listener.errors.count)
        session.close()
    }
    
    func testSession_IcySwr3() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://swr-swr3.cast.ybrid.io/swr/swr3/ybrid")
        guard let session = endpoint.open(listener: listener) else {
            XCTFail("session expected"); return
        }
        let playbackUri = session.playbackUri
        XCTAssertEqual(endpoint.uri, playbackUri)
        let metadata = session.fetchMetadataSync()
        XCTAssertNil(metadata, "no icy metadata expected")
        XCTAssertEqual(0, listener.errors.count)
        session.close()
    }
    
    func testSession_DlfOpus() throws {
        let uri = "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus"
        let endpoint = MediaEndpoint(mediaUri: uri)
        guard let session = endpoint.open(listener: listener) else {
            XCTFail("session expected"); return
        }
        let playbackUri = session.playbackUri
        XCTAssertEqual(uri, playbackUri)
        
        let metadata = session.fetchMetadataSync()
        XCTAssertNil(metadata, "no opus metadata expected")
        XCTAssertEqual(0, listener.errors.count)
        session.close()
    }
    
    func testSession_OnDemandSound() throws {
        let uri = "https://github.com/ybrid/test-files/blob/main/mpeg-audio/music/organ.mp3?raw=true"
        let endpoint = MediaEndpoint(mediaUri:uri)
        guard let session = endpoint.open(listener: listener) else {
            XCTFail("session expected"); return
        }
        let playbackUri = session.playbackUri
        XCTAssertEqual(uri, playbackUri)
        let metadata = session.fetchMetadataSync()
        XCTAssertNil(metadata, "no metadata expected")
        XCTAssertEqual(0, listener.errors.count)
        session.close()
    }
    
    

    func testSession_BadUrl() throws {
        let uri = "https://blub"
        let endpoint = MediaEndpoint(mediaUri:uri)
        let session = endpoint.open(listener: listener)
        XCTAssertNil(session, "no session expected")
        XCTAssertEqual(1,listener.errors.count)
        let error = listener.errors[0]
        XCTAssertNotEqual(0,error.code)
    }
    
    
    class MediaListener : MediaEndpointListener {
        var errors:[AudioPlayerError] = []
        func error(_ severity: ErrorSeverity, _ exception: AudioPlayerError) {
            errors.append(exception)
        }
    }
}
