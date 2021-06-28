//
// MediaSessionTests.swift
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
        guard let player = AudioPlayer.openSync(for: ybridDemoEndpoint, listener: listener) else {
            XCTFail("player expected"); return
        }
        let playbackUri = player.session.playbackUri
        XCTAssertTrue(playbackUri.starts(with: "icyx"))
        XCTAssertTrue(playbackUri.contains("edge"))
        guard let metadata = player.session.fetchMetadataSync() else {
            XCTFail("ybrid metadata expected"); return
        }
        print("running \(metadata.displayTitle ?? "(nil)")")
        XCTAssertNotNil(metadata)
        XCTAssertEqual(0, listener.errors.count)
        player.close()
    }
    
    
    

    func testSession_YbridSwr3() throws {
        guard let player = AudioPlayer.openSync(for: ybridSwr3Endpoint, listener: listener) else {
            XCTFail("player expected"); return
        }
        let playbackUri = player.session.playbackUri
        XCTAssertTrue(playbackUri.starts(with: "icyx"))
        XCTAssertTrue(playbackUri.contains("edge"))
        guard let metadata = player.session.fetchMetadataSync() else {
            XCTFail("ybrid metadata expected"); return
        }
        print("running \(metadata.displayTitle ?? "(nil")")
        XCTAssertEqual(0, listener.errors.count)
        player.close()
    }
    
    func testSession_IcySwr3() throws {

        guard let player = AudioPlayer.openSync(for:icecastSwr3Endpoint, listener: listener) else {
            XCTFail("player expected"); return
        }
        let playbackUri = player.session.playbackUri
        XCTAssertEqual(icecastSwr3Endpoint.uri, playbackUri)
        let metadata = player.session.fetchMetadataSync()
        XCTAssertNil(metadata, "no icy metadata expected")
        XCTAssertEqual(0, listener.errors.count)
        player.close()
    }
    
    func testSession_DlfOpus() throws {

        guard let player = AudioPlayer.openSync(for: opusDlfEndpoint, listener: listener) else {
            XCTFail("player expected"); return
        }
        let playbackUri = player.session.playbackUri
        XCTAssertEqual(opusDlfEndpoint.uri, playbackUri)
        
        let metadata = player.session.fetchMetadataSync()
        XCTAssertNil(metadata, "no opus metadata expected")
        XCTAssertEqual(0, listener.errors.count)
        player.close()
    }
    
    func testSession_OnDemandSound() throws {
        let uri = "https://github.com/ybrid/test-files/blob/main/mpeg-audio/music/organ.mp3?raw=true"
        let endpoint = MediaEndpoint(mediaUri:uri)
        guard let player = AudioPlayer.openSync(for: endpoint, listener: listener) else {
            XCTFail("player expected"); return
        }

        let playbackUri = player.session.playbackUri
        XCTAssertEqual(uri, playbackUri)
        let metadata = player.session.fetchMetadataSync()
        XCTAssertNil(metadata, "no metadata expected")
        XCTAssertEqual(0, listener.errors.count)
        player.close()
    }
    
    
    func testSession_NoMediaUrl() throws {
        let uri = "https://stagecast.ybrid.io/xyzbnlabla"
        let endpoint = MediaEndpoint(mediaUri:uri)
        guard let player = AudioPlayer.openSync(for: endpoint, listener: listener) else {
            XCTFail("player expected"); return
        }
        sleep(1) // the listener is notified asynchronously
        XCTAssertNotNil(player.session, "session expected")
        XCTAssertEqual(0,listener.errors.count)

    }
    
    func testSession_BadUrl() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://blub")
        let player = AudioPlayer.openSync(for: endpoint, listener: listener)
        XCTAssertNil(player, "no player expected")
        
        sleep(1) // the listener is notified asynchronously
        XCTAssertEqual(1,listener.errors.count)
        let error = listener.errors[0]
        XCTAssertNotEqual(0,error.code)
    }
    
    
    class MediaListener : AudioPlayerListener {
        func stateChanged(_ state: PlaybackState) {}
        func metadataChanged(_ metadata: Metadata) {}
        func playingSince(_ seconds: TimeInterval?) {}
        func durationReadyToPlay(_ seconds: TimeInterval?) {}
        func durationConnected(_ seconds: TimeInterval?) {}
        func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {}
        
        var errors:[AudioPlayerError] = []
        func error(_ severity: ErrorSeverity, _ exception: AudioPlayerError) {
            errors.append(exception)
        }
    }
}
