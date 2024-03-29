//
// MediaProtocolTests.swift
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

class MediaProtocolTests: XCTestCase {
    
    let factory = MediaControlFactory()
    
    // Demo
    
    func testYbridDemo_GetVersion_AutodetectYbrid() throws {
        let version = try factory.getVersion("https://democast.ybrid.io/adaptive-demo")
        XCTAssertEqual(MediaProtocol.ybridV2, version)
    }
    
    func testYbridDemo_Driver_State_Disconnect() throws {
        let endpoint = ybridDemoEndpoint
        guard let player = AudioPlayer.openSync(for: endpoint, listener: nil) else {
            XCTFail("expected a player"); return
        }
        guard let session = (player as? YbridAudioPlayer)?.session else {
            XCTFail("expected a ybrid session"); return
        }
        let v2 = session.driver!
        XCTAssertEqual(MediaProtocol.ybridV2, v2.mediaProtocol)
        XCTAssertTrue(v2.connected)
        let state = session.mediaState!
        XCTAssertTrue(state.valid)
        XCTAssertNotNil(state.playbackUri)
        XCTAssertTrue(state.playbackUri.starts(with: "icyx"))
      
        v2.disconnect()
        XCTAssertFalse(v2.connected)
    }
    
    func testYbridDemo_Connect_Connect() throws {
        guard let player = AudioPlayer.openSync(for: ybridDemoEndpoint, listener: nil) else {
            XCTFail("expected a player"); return
        }
        guard let driver = player.session.driver else {
            XCTFail("expected a driver"); return
        }
        XCTAssertEqual(MediaProtocol.ybridV2, driver.mediaProtocol)
        XCTAssertTrue(driver.connected)
        guard let state = player.session.mediaState else {
            XCTFail("expected a state"); return
        }
        var playbackUri = state.playbackUri
        XCTAssertTrue(playbackUri.starts(with: "icyx"))
        XCTAssertTrue(playbackUri.contains("edge"))
        
        try driver.connect()
        XCTAssertTrue(driver.connected)
        playbackUri = state.playbackUri
        XCTAssertTrue(playbackUri.starts(with: "icyx"))
        XCTAssertTrue(playbackUri.contains("edge"))
    }
    
    func testYbridAdDemo_GetVersion_AutodetectYbrid() throws {
        let version = try factory.getVersion(ybridAdDemoEndpoint.uri)
        XCTAssertEqual(MediaProtocol.ybridV2, version)
    }
    
    // Stage
    
    func testYbridStageDemo_GetVersion_NoAutodetectYbrid() throws {
        let version = try factory.getVersion(ybridStageDemoEndpoint.uri)
        XCTAssertEqual(MediaProtocol.icy, version)
    }
    
    func testYbridStageDemo_YbridV2MustBeForced() throws {
        let endpoint = ybridStageDemoEndpoint
        
        guard let player = AudioPlayer.openSync(for:endpoint, listener: nil) else {
            XCTFail("expected a player"); return
        }
        guard let driver = player.session.driver as? IcyDriver else {
            XCTFail("expected an icy driver"); return
        }
        XCTAssertEqual(MediaProtocol.icy, driver.mediaProtocol)
        XCTAssertTrue(driver.connected)

        guard let state = player.session.mediaState else {
            XCTFail("expected a state"); return
        }
        XCTAssertTrue(state.playbackUri.starts(with:"https://"))
        
        player.close()
        XCTAssertFalse(driver.connected)
        
//        endpoint = endpoint.forceProtocol(.ybridV2)
//        guard let player = AudioPlayer.openSync(for: endpoint, listener: nil) else {
//            XCTFail("expected a player"); return
//        }
//        guard let driver = player.session.driver as? YbridV2Driver else {
//            XCTFail("expected a v2 driver"); return
//        }
//        XCTAssertEqual(MediaProtocol.ybridV2, driver.mediaProtocol)
//        XCTAssertTrue(driver.connected)
//
//        guard let state = player.session.mediaState else {
//            XCTFail("expected a state"); return
//        }
//        XCTAssertNotNil(state.playbackUri)
//        XCTAssertTrue(state.playbackUri.starts(with: "icyx"))
//        XCTAssertTrue(state.playbackUri.contains("edge"))
//
//        XCTAssertEqual(endpoint.uri, player.session.playbackUri)
//
//        driver.disconnect()
//        XCTAssertFalse(driver.connected)
    }
    
    func testYbridStageSwr3_GetVersion_AutodetectYbrid() throws {
        let version = try factory.getVersion(ybridStageSwr3Endpoint.uri)
        XCTAssertEqual(MediaProtocol.ybridV2, version)
    }
    
    func testYbridStageSwr3_Driver_State() throws {
        let endpoint = ybridStageSwr3Endpoint
        
        guard let player = AudioPlayer.openSync(for:endpoint, listener: nil) else {
            XCTFail("expected a player"); return
        }
        guard let driver = player.session.driver as? YbridV2Driver else {
            XCTFail("expected an icy driver"); return
        }
        XCTAssertEqual(MediaProtocol.ybridV2, driver.mediaProtocol)
        XCTAssertTrue(driver.connected)

        
        guard let state = player.session.mediaState else {
            XCTFail("expected a state"); return
        }
        XCTAssertTrue(state.valid)
        
        XCTAssertNotNil(state.playbackUri)
        XCTAssertTrue(state.playbackUri.starts(with: "icyx"))
        XCTAssertTrue(state.playbackUri.contains("edge"))
        
        player.close()
        XCTAssertFalse(driver.connected)
    }
    
    
    // none
    
    func testGetVersion_wrongUrl_AutodetectIcy() throws {
        let version = try factory.getVersion("https://stagecast.ybrid.io/swr3/mp3")
        XCTAssertEqual(MediaProtocol.icy, version)
    }
    
    func testGetVersion_UrlNotFound_AutodetectIcy() throws {
        let version = try factory.getVersion("https://stagecast.ybrid.io/gibtsNicht")
        XCTAssertEqual(MediaProtocol.icy, version)
    }

    func testGetVersion_BadUrl_ThrowsError() throws {
        do {
            _ = try factory.getVersion("no url")
        } catch {
            XCTAssertTrue(error is SessionError)
            return
        }
        XCTFail()
    }
    
    func testDriver_Swr3WrongUrl_Connect() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://stagecast.ybrid.io/swr3/mp3")
        guard let player = AudioPlayer.openSync(for:endpoint, listener: nil) else {
            XCTFail("expected a player"); return
        }
        XCTAssertNotNil(player.session.driver)
        
        XCTAssertEqual(endpoint.uri, player.session.playbackUri)
    }

    // on demand mp3s
    
    func testOnDemand_GetVersion_AutodetectIcy() throws {
        let version = try factory.getVersion("https://github.com/ybrid/test-files/blob/main/mpeg-audio/music/organ.mp3?raw=true")
        XCTAssertEqual(MediaProtocol.icy, version)
    }
    
    func testOnDemand_Driver() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://github.com/ybrid/test-files/blob/main/mpeg-audio/music/organ.mp3?raw=true")
        guard let player = AudioPlayer.openSync(for:endpoint, listener: nil) else {
            XCTFail("expected a player"); return
        }
        guard let icy = player.session.mediaState as? IcyState else {
            XCTFail("expected an icy session"); return
        }
        XCTAssertEqual(endpoint.uri, icy.playbackUri)
        
        guard let icyDriver = player.session.driver as? IcyDriver else {
            XCTFail("expected an icy driver"); return
        }
        
        XCTAssertEqual(MediaProtocol.icy, icyDriver.mediaProtocol)
        XCTAssertTrue(icyDriver.connected)
    }
    
    
    // prod
    
    func testGetVersion_Hr2_AutodetectIcy() throws {
        let version = try factory.getVersion("https://hr-hr2-live.cast.addradio.de/hr/hr2/live/mp3/128/stream.mp3")
        XCTAssertEqual(MediaProtocol.icy, version)
    }
    
    func testHr2_PlaybackUri() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://hr-hr2-live.cast.addradio.de/hr/hr2/live/mp3/128/stream.mp3")
        guard let player = AudioPlayer.openSync(for:endpoint, listener: nil) else {
            XCTFail("expected a player"); return
        }
        guard let icyDriver = player.session.driver as? IcyDriver else {
            XCTFail("expected an icy driver"); return
        }
        XCTAssertEqual(MediaProtocol.icy, icyDriver.mediaProtocol)
        XCTAssertTrue(icyDriver.connected)
        
        
        guard let icy = player.session.mediaState as? IcyState else {
            XCTFail("expected an icy session"); return
        }
        XCTAssertEqual(endpoint.uri, icy.playbackUri)
    }
    
    func testEgoFM_PlaybackUri() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://egofm-live.cast.addradio.de/egofm/live/mp3/high/stream.mp3")
        guard let player = AudioPlayer.openSync(for:endpoint, listener: nil) else {
            XCTFail("expected a player"); return
        }
        guard let icyDriver = player.session.driver as? IcyDriver else {
            XCTFail("expected an icy driver"); return
        }
        XCTAssertEqual(MediaProtocol.icy, icyDriver.mediaProtocol)
        XCTAssertTrue(icyDriver.connected)
        
        guard let icy = player.session.mediaState as? IcyState else {
            XCTFail("expected an icy session"); return
        }
        XCTAssertEqual(endpoint.uri, icy.playbackUri)
    }
    
    func testDlfOpus_PlaybackUri() throws {
        let endpoint = MediaEndpoint(mediaUri:"https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")
        guard let player = AudioPlayer.openSync(for:endpoint, listener: nil) else {
            XCTFail("expected a player"); return
        }
        let session = player.session
        XCTAssertTrue(session.driver?.connected ?? false)
        XCTAssertEqual(MediaProtocol.icy, session.driver?.mediaProtocol)
        XCTAssertEqual(endpoint.uri, session.mediaState?.playbackUri)
    }
    
 
    
}
