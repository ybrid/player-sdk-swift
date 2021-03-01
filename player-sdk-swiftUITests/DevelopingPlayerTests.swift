//
// DevelopingPlayerTests.swift
// player-sdk-swiftTests
//
// Copyright (c) 2020 nacamar GmbH - Ybrid®, a Hybrid Dynamic Live Audio Technology
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

import YbridPlayerSDK
import YbridOpus
import YbridOgg


class DevelopingPlayerTests: XCTestCase {
 
    func test01_PlayerBundle() {
        let version = checkBundle(id: "io.ybrid.player-sdk-swift", expectedName: "YbridPlayerSDK")
        XCTAssertNotNil(version)
//        XCTAssertEqual("0.6.1", version)
    }

    func test02_VersionString() {
        Logger.verbose = false
        let version = AudioPlayer.versionString
        Logger.testing.notice("-- \(version)")
        XCTAssert(version.contains("YbridPlayerSDK"), "should contain player-sdk-swiftTests")
    }

    func test03_PlayMp3() {
        Logger.verbose = true
        let url = URL.init(string: "https://swr-swr3.cast.ybrid.io/swr/swr3/ybrid")!
        let playerListener = TestAudioPlayerListener()
        let player = AudioPlayer(mediaUrl: url, listener: playerListener)
        player.play()
        sleep(6)
        player.stop()
        sleep(1)
    }
    
     private func checkBundle(id:String, expectedName:String) -> String? {
        guard let bundle = Bundle(identifier: id) else {
            XCTFail("no bundle identifier '\(id)' found")
            return nil
        }
        guard let info = bundle.infoDictionary else {
            XCTFail("no infoDictionary on bundle '\(id)' found")
            return nil
        }
        print("-- infoDictionary is '\(info)'")
        
        let version = info["CFBundleShortVersionString"] as! String
        XCTAssertNotNil(version)

        let name = info["CFBundleName"] as! String
        XCTAssertEqual(expectedName, name)
        let copyright = info["NSHumanReadableCopyright"] as! String
        XCTAssertTrue(copyright.contains("nacamar"))
        
        let build = info["CFBundleVersion"] as! String
        print("-- version of \(name) is \(version) (build \(build))")
        
        return version
    }
    
    func test04_OpusBundleInfo() throws {
        let version = checkBundle(id: "io.ybrid.opus-swift", expectedName: "YbridOpus")
        XCTAssertNotNil(version)
//        XCTAssertEqual("0.7.0", version)
    }
    
    func test05_YbridOpusAvailable() {
        let versionString = String(cString: opus_get_version_string())
        print("-- opus_get_version_string() returns '\(versionString)\'")
        XCTAssertTrue(versionString.hasPrefix("libopus 1.3.1"))
    }
    
    func test06_OggBundleInfo() throws {
        let version = checkBundle(id: "io.ybrid.ogg-swift", expectedName: "YbridOgg")
        XCTAssertNotNil(version)
//        XCTAssertEqual("0.7.2", version)
    }
    
    func test07_YbridOggAvailable() {
        var oggSyncState = ogg_sync_state()
        print("-- ogg_sync_state() is '\(oggSyncState)\'")
        XCTAssertNotNil(oggSyncState)
        XCTAssertEqual(0, oggSyncState.returned)
        ogg_sync_init(&oggSyncState)
        ogg_sync_clear(&oggSyncState)
        print("-- ogg_sync_state() is '\(oggSyncState)\'")
        XCTAssertEqual(0, oggSyncState.returned)
    }
    
    func test08_PlayOpus() {
        Logger.verbose = false
        let opus = URL.init(string:  "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")!
        let player = AudioPlayer(mediaUrl: opus, listener: nil)
        player.play()
        sleep(6)
        player.stop()
        sleep(1)
    }

}
