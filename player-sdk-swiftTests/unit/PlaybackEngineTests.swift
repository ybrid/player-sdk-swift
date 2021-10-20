//
//  PlaybackEngineTests.swift
//  app-example-iosTests
//
//  Created by Florian Nowotny on 11.09.20.
//  Copyright © 2020 Florian Nowotny. All rights reserved.
//

import XCTest
import AVFoundation
@testable import YbridPlayerSDK

class PlaybackEngineTests: XCTestCase {
    
    static let format48 = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 2, interleaved: false)!
    
    // These values depend on the device
    static let aboluteTimeAccuracyS = 0.3
    static let relativeTimeAccuracyS = 0.01
    static let outputLatencyToleranceS = 0.02
        
    var engine = PlaybackEngine(format: format48, infinite: true, listener: nil)
    var buffer:PlaybackBuffer?
    var format:AVAudioFormat { return PlaybackEngineTests.format48 }
    var sampleRate:Double { PlaybackEngineTests.format48.sampleRate }
    var oneSec:Int64 { return Int64(sampleRate) }
    
    override func setUpWithError() throws {
        try super.setUpWithError()
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        self.engine.stop()
    }
    
    func testEngineInitialized() throws {
        XCTAssertEqual(48000, engine.sampleRate)
        XCTAssertNotNil(engine.engine)
        XCTAssertNotNil(engine.playerNode)
        XCTAssertFalse(engine.playerNode.isPlaying)
        XCTAssertFalse(engine.engine.isRunning)

        XCTAssertEqual(1, engine.engine.mainMixerNode.volume)
        XCTAssertEqual(1, engine.engine.mainMixerNode.outputVolume)
        XCTAssertEqual(0.0, engine.engine.mainMixerNode.pan)
        
  
        if #available(iOS 11.0, macOS 10.13, *) {
            XCTAssertFalse(engine.engine.isInManualRenderingMode)
            XCTAssertGreaterThan(PlaybackEngineTests.outputLatencyToleranceS, engine.playerNode.outputPresentationLatency)
        } else {
                /// no fallback on earlier versions
            }
        XCTAssertEqual(format, engine.playerNode.outputFormat(forBus: 0))
    }
    
    func testEngineStartAndStop() throws {
        buffer = engine.start()
        XCTAssertTrue(engine.playerNode.isPlaying)
        XCTAssertTrue(engine.engine.isRunning)
   
        engine.stop()
        XCTAssertFalse(engine.playerNode.isPlaying)
        XCTAssertFalse(engine.engine.isRunning)
        
        let playerStarted = buffer?.scheduling.playerNow
        XCTAssertNil(playerStarted)
 
    }
    
    func testEngine_NodeTime() throws {
        
//        XCTAssertNil(engine.playbackBuffer?.scheduling.nodeNow)
        
        buffer = engine.start()
        let nodeStarted = buffer?.scheduling.nodeNow
        XCTAssertNotNil(nodeStarted)
        XCTAssertTrue(nodeStarted!.isSampleTimeValid)
        XCTAssertTrue(nodeStarted!.isHostTimeValid)
        
        /// node time start value is not defined (can start on 0, but differs on device)
        let nodeStartedS = Double(nodeStarted!.sampleTime) / format.sampleRate
        print ("node time started \(nodeStartedS) s")
        
        sleep(1)
        guard let node1SecLater = buffer?.scheduling.nodeNow else { XCTFail(); return }
        /// but you can be shure about the difference
        let node1SecLaterS = Double(node1SecLater.sampleTime) / format.sampleRate
        print ("node time 1 sec later \(node1SecLaterS) s")
        XCTAssertEqual( 1.0, node1SecLaterS - nodeStartedS, accuracy: PlaybackEngineTests.relativeTimeAccuracyS )
        
        engine.stop()
        XCTAssertNil(buffer?.scheduling.nodeNow)
    }
    
    func testEngine_NodeTimeStopStart() throws {
        
        buffer = engine.start()
        guard let nodeBeforeStop = buffer?.scheduling.nodeNow else { XCTFail(); return }
        DispatchQueue.global().async { self.engine.stop() }
        sleep(3)
        let now = Date()
        engine.start()
        let playTookS = Date().timeIntervalSince(now)
        print("play took \(playTookS) seconds")
        guard let nodeResumed = buffer?.scheduling.nodeNow else { XCTFail(); return }
        
        let nodeBeforeStopS = Double(nodeBeforeStop.sampleTime) / format.sampleRate
        let nodeResumedS = Double(nodeResumed.sampleTime) / format.sampleRate
        XCTAssertEqual( 3.0, nodeResumedS - nodeBeforeStopS - playTookS, accuracy: PlaybackEngineTests.relativeTimeAccuracyS )
        
        engine.stop()
    }
    
    func testEngine_PlayerTime() throws {
//        XCTAssertNil(engine.playbackBuffer?.scheduling.started)
        
        buffer = engine.start()
        let playerStarted = buffer?.scheduling.playerNow
        XCTAssertNotNil(playerStarted)
        XCTAssertTrue(playerStarted!.isSampleTimeValid)
        XCTAssertTrue(playerStarted!.isHostTimeValid)
        
        /// player time is 0 (+/- 0.01s) on play
        let playerStartedS = Double(playerStarted!.sampleTime) / format.sampleRate
        XCTAssertEqual( 0.0, playerStartedS, accuracy: PlaybackEngineTests.aboluteTimeAccuracyS, "expected player time 0 s, but is \(playerStartedS)"  )
        
        sleep(1)
        guard let player1SecLater = buffer?.scheduling.playerNow else { XCTFail(); return }
        /// ensure player time is 1 sec later
        let playerLaterS = Double(player1SecLater.sampleTime) / format.sampleRate
        XCTAssertEqual( 1.0, playerLaterS - playerStartedS, accuracy: PlaybackEngineTests.relativeTimeAccuracyS, "expected player time 1 s, but is \(playerLaterS - playerStartedS)" )
        
        engine.stop()
    }
    
    func testEngine_PlayerTimeStopStart() throws {
        buffer = engine.start()
        guard let playerStarted = buffer?.scheduling.playerNow else { XCTFail(); return }
        /// player time is 0 (+/- 0.01) seconds
        let playerStartedS = Double(playerStarted.sampleTime) / format.sampleRate
        XCTAssertEqual( 0.0, playerStartedS, accuracy: PlaybackEngineTests.aboluteTimeAccuracyS, "expected player time 0 s, but is \(playerStartedS)"  )
        
        engine.stop()
        sleep(3)
        engine.start()
        
        guard let playerLater = buffer?.scheduling.playerNow else { XCTFail(); return }
        /// player time starts with 0 again
        let playerLaterS = Double(playerLater.sampleTime) / format.sampleRate
        XCTAssertEqual( 0.0, playerLaterS, accuracy: PlaybackEngineTests.aboluteTimeAccuracyS, "expected player time 0 s, but is \(playerLaterS)"  )
        
        engine.stop()
    }
}
