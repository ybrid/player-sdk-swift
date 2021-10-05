//
// SteelinessTests.swift
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

class YbridSteelinessTests: XCTestCase {
    
    let listener = ErrorListener()
    func testSteelinessStage_InfoResponse_WithoutMillisHappen() throws {
        guard let player = AudioPlayer.openSync(for: ybridStageDemoEndpoint, listener: listener) else {
            XCTFail("player expected"); return
        }
        for i in 1...5000 {
            if i % 25 == 0 {
                print("session info \(i)")
            }
            player.session.refresh()
        }
        
        player.close()
    }
  
   
    func testSteelinessProd_InfoResponse_WithoutMillisHappen() throws {
        guard let player = AudioPlayer.openSync(for: ybridSwr3Endpoint.forceProtocol(.ybridV2), listener: listener) else {
            XCTFail("player expected"); return
        }
        for i in 1...5000 {
            player.session.refresh()
            if i % 25 == 0 {
                print("session info \(i)")
            }
        }
        
        player.close()
    }
  
    func testSteelinessSession_OptionsCreateClose() throws {
        for i in 1...1000 {
          
            guard let player = AudioPlayer.openSync(for: ybridStageDemoEndpoint, listener: listener) else {
                XCTFail("player expected");
                continue
            }
            if i % 25 == 0 {
                print("options create close session \(i)")
            }
            player.close()
        }
    }

    func testSteelinessSession_CreateClose() throws {
        for i in 1...1000 {
          
            guard let player = AudioPlayer.openSync(for: ybridStageDemoEndpoint.forceProtocol(.ybridV2), listener: listener) else {
                XCTFail("player expected");
                continue
            }
            if i % 25 == 0 {
                print("options create close session \(i)")
            }
            player.close()
        }
    }
   
    
    func testPlaybackUriStatistic() throws {
        let semaphore = DispatchSemaphore(value: 0)
        let listener = ErrorListener()

        var playbackUris:[String] = []
        for i in (1...50) {
            try AudioPlayer.open(for: ybridSwr3Endpoint, listener: listener,
                                 playbackControl: { (c) in return },
                                 ybridControl: {
                (ybridControl) in
                if let ybrid = ybridControl as? YbridAudioPlayer {
                    let uri = ybrid.session.playbackUri
                    print( "playbackUri is \(uri)")
                    playbackUris.append(uri)
                    
                    
                }
                if i % 25 == 0 {
                    print(" \(i) created sessions")
                }
                ybridControl.close()
            })
            sleep(1)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        let pbUrls:[URL] = playbackUris.map {
            let url = URL(string: $0)!
            var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            comps.query = nil
            return comps.url!
        }
        var uriCount: [URL:Int] = [:]
        let uniqueUris = Set(pbUrls)
        uniqueUris.forEach{ let uri = $0; let count = pbUrls.filter{$0==uri}.count;
            uriCount[uri] = count
        }
        print("different uris are \(uriCount)")
        print("\(listener.errors.count) errors occured")
    }
   
    func testBaseURLsStatistic() throws {
        let semaphore = DispatchSemaphore(value: 0)
        let listener = ErrorListener()

        var baseURLs:[URL] = []
        for i in 1...50 {
            try AudioPlayer.open(for: ybridSwr3Endpoint, listener: listener,
                                 playbackControl: { (c) in return },
                                 ybridControl: {
                (ybridControl) in
                if let ybrid = ybridControl as? YbridAudioPlayer {
                    if let base = ybrid.session.mediaState?.baseUrl {
                        print("base url is \(base)")
                        baseURLs.append(base)
                    }
                }
                if i % 25 == 0 {
                    print(" \(i) created sessions")
                }
                ybridControl.close()
            })
            sleep(1)
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .distantFuture)
        
        let baseHosts:[URL] = baseURLs.map {
            var comps = URLComponents(url: $0, resolvingAgainstBaseURL: false)!
            comps.query = nil
            return comps.url!
        }
        var baseUrlCount: [URL:Int] = [:]
        let uniqueBaseUrls = Set(baseHosts)
        uniqueBaseUrls.forEach{ let uri = $0; let count = baseHosts.filter{$0==uri}.count;
            baseUrlCount[uri] = count
        }
        print("different base urls are \(baseUrlCount)")
        print("\(listener.errors.count) errors occured")
    }
   
    func testReconnectSession_Swr3_InternallyFromEndpointUri() throws {
        let semaphore = DispatchSemaphore(value: 0)
        let listener = ErrorListener()

        try AudioPlayer.open(for: ybridSwr3Endpoint, listener: listener,
             playbackControl: { (c) in
                XCTFail("should be ybrid")
                semaphore.signal() },
             ybridControl: { (ybridControl) in
                if let ybrid = ybridControl as? YbridAudioPlayer {
                    if let yState = ybrid.session.mediaState as? YbridState,
                    let yDriver = ybrid.session.driver as? YbridV2Driver {
                        print("base uri is \(yState.baseUrl)")
                        let baseUrlOrig = yState.baseUrl
                        
                        // forcing to reconnect
                        do {
                            try yDriver.reconnect()
                        } catch {
                            Logger.session.error(error.localizedDescription)
                            XCTFail("should work, but \(error.localizedDescription)")
                        }
                        print("base uri is \(yState.baseUrl)")
                        let baseUrlReconnected = yState.baseUrl
                        XCTAssertNotEqual(baseUrlOrig, baseUrlReconnected)
                        
                        ybrid.play()
                        print("base uri is \(yState.baseUrl)")
                    }
                }
                sleep(4)
                semaphore.signal()
             })
        _ = semaphore.wait(timeout: .distantFuture)
        let errCount = listener.errors.count
        guard errCount == 0 else {
            XCTAssertEqual(1, errCount, "\(errCount) errors occured")
            let err = listener.errors[0]
            Logger.session.error(err.localizedDescription)
            XCTFail("cannot play on reconnected session, \(String(describing: err.message))")
            return
        }
    }
   
    func testReconnectSession_Demo_ok() throws {
        let semaphore = DispatchSemaphore(value: 0)
        let listener = ErrorListener()

        try AudioPlayer.open(for: ybridDemoEndpoint, listener: listener,
             playbackControl: { (c) in
                return },
             ybridControl: { (ybridControl) in
                if let ybrid = ybridControl as? YbridAudioPlayer {
                    if let yState = ybrid.session.mediaState as? YbridState,
                       let yDriver = ybrid.session.driver as? YbridV2Driver {
                        print("base uri is \(yState.baseUrl)")
                        let baseUrlOrig = yState.baseUrl
                        
                        // forcing to reconnect
                        do {
                            try yDriver.reconnect()
                        } catch {
                            Logger.session.error(error.localizedDescription)
                            XCTFail("should work, but \(error.localizedDescription)")
                        }
                        print("base uri is \(yState.baseUrl)")
                        let baseUrlReconnected = yState.baseUrl
                        XCTAssertEqual(baseUrlOrig, baseUrlReconnected)
 
                    
                        ybrid.play()
                        print("base uri is \(yState.baseUrl)")
                    }
                }
                sleep(4)
                ybridControl.close()
                semaphore.signal()
             })
        _ = semaphore.wait(timeout: .distantFuture)
        let errCount = listener.errors.count
        guard errCount == 0 else {
            XCTFail("recreating session should work")
            return
        }
    }
   
 
}
