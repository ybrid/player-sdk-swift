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
@testable import YbridPlayerSDK

class MediaSessionTests: XCTestCase {

    let listener = MediaListener()
    override func setUpWithError() throws {
        listener.cleanUp()
    }

    override func tearDownWithError() throws {
    }
    
    func testSession_YbridDemo() throws {
        let session = MediaSession(on:ybridDemoEndpoint, playerListener: listener)
        XCTAssertNotNil(session.playerListener)
        try session.connect()
        let player = AudioPlayer(session: session)
        XCTAssertNotNil(player.playerListener)
        
        let playbackUri = session.playbackUri
        XCTAssertTrue(playbackUri.starts(with: "icyx"))
        XCTAssertTrue(playbackUri.contains("edge"))
        
        session.notifyChanged(SubInfo.metadata)
        usleep(10_000)
        guard let metadata = listener.metadatas.first else {
            XCTFail("metadata expected"); return
        }
 
        print("running \(metadata.displayTitle ?? "(nil)")")
        XCTAssertNotNil(metadata)
        
        XCTAssertEqual(0, listener.errors.count)
        player.close()
    }

    func testSession_YbridSwr3() throws {

        let session = MediaSession(on: ybridSwr3Endpoint, playerListener: listener)
        try session.connect()
        let player = AudioPlayer(session: session)
        let playbackUri = player.session.playbackUri
        XCTAssertTrue(playbackUri.starts(with: "icyx"))
        
        session.notifyChanged(SubInfo.metadata)
        usleep(10_000)
        guard let metadata = listener.metadatas.first else {
            XCTFail("metadata expected"); return
        }
        
        print("running \(metadata.displayTitle ?? "(nil")")
        XCTAssertEqual(0, listener.errors.count)
        player.close()
    }
    
    func testSession_IcySwr3() throws {

        let session = MediaSession(on: icecastSwr3Endpoint, playerListener: listener)
        try session.connect()
        let player = AudioPlayer(session: session)
        
        let playbackUri = player.session.playbackUri
        XCTAssertEqual(icecastSwr3Endpoint.uri, playbackUri)
        
        session.notifyChanged(SubInfo.metadata)
        usleep(10_000)
        let metadata = listener.metadatas.first
        XCTAssertNil(metadata, "no metadata expected")
        XCTAssertEqual(0, listener.errors.count)
        player.close()
    }
    
    func testSession_DlfOpus() throws {
        let session = MediaSession(on: opusDlfEndpoint, playerListener: listener)
        try session.connect()
        let player = AudioPlayer(session: session)
        let playbackUri = player.session.playbackUri
        XCTAssertEqual(opusDlfEndpoint.uri, playbackUri)
        
        session.notifyChanged(SubInfo.metadata)
        usleep(10_000) // the listener is notified asynchronously
        let metadata = listener.metadatas.first
        XCTAssertNil(metadata, "no metadata expected")
        XCTAssertEqual(0, listener.errors.count)
        player.close()
    }
    
    func testSession_OnDemandSound() throws {
        let uri = "https://github.com/ybrid/test-files/blob/main/mpeg-audio/music/organ.mp3?raw=true"
        let endpoint = MediaEndpoint(mediaUri:uri)
        let session = MediaSession(on: endpoint, playerListener: listener)
        try session.connect()
        let player = AudioPlayer(session: session)

        let playbackUri = session.playbackUri
        XCTAssertEqual(uri, playbackUri)
        
        session.notifyChanged(SubInfo.metadata)
        usleep(10_000) // the listener is notified asynchronously
        let metadata = listener.metadatas.first
        XCTAssertNil(metadata, "no metadata expected")
        XCTAssertEqual(0, listener.errors.count)
        player.close()
    }
    
    func testSession_NoMediaUrl() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://stagecast.ybrid.io/xyzbnlabla")
        let session = MediaSession(on: endpoint, playerListener: listener)
        try session.connect()
        let player = AudioPlayer(session: session)
        usleep(10_000) // the listener is notified asynchronously
        XCTAssertNotNil(player.session, "no session expected")
        XCTAssertEqual(0,listener.errors.count)
    }
    
    func testSession_BadUrl() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://blub")
        let session = MediaSession(on: endpoint, playerListener: listener)
        session.playerListener = listener
        do {
            _ = try session.connect()
            XCTFail(); return
        } catch {
            XCTAssertTrue( error is SessionError )
        }
//        let player = AudioPlayer(session: session, abstract: abstractSession)
//        XCTAssertNotNil(player, "player expected")

        usleep(10_000) // the listener is notified asynchronously
        guard let error = listener.errors.first else {
            XCTFail(); return
        }
        XCTAssertEqual(1,listener.errors.count)
        XCTAssertNotEqual(0,error.code)
    }
    
    class MediaListener : AudioPlayerListener {

        var metadatas:[Metadata] = []
        var errors:[AudioPlayerError] = []

        func cleanUp() {
            metadatas.removeAll()
            errors.removeAll()
        }

        func metadataChanged(_ metadata: Metadata) {
            metadatas.append(metadata)
        }
        func error(_ severity: ErrorSeverity, _ exception: AudioPlayerError) {
            errors.append(exception)
        }
        
        func stateChanged(_ state: PlaybackState) {}
        func playingSince(_ seconds: TimeInterval?) {}
        func durationReadyToPlay(_ seconds: TimeInterval?) {}
        func durationConnected(_ seconds: TimeInterval?) {}
        func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {}
    }
}
