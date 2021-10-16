//
//  PlaybackSchedulingTests.swift
//  app-example-iosTests
//
//  Created by Florian Nowotny on 13.09.20.
//  Copyright © 2020 Florian Nowotny. All rights reserved.
//

import XCTest
import AVFoundation
@testable import YbridPlayerSDK

let format48 = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 2, interleaved: false)!

@available(iOS 11.0, macOS 10.13,  *)
class PlaybackSchedulingTests: XCTestCase {
    
    
    var format:AVAudioFormat { return PlaybackEngineTests.format48 }
    var sampleRate:Double { PlaybackEngineTests.format48.sampleRate }
    var oneSec:Int64 { return Int64(sampleRate) }
    
    var engine:PlaybackEngine?
    var playbackBuffer:PlaybackBuffer?
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        engine = PlaybackEngine(format: format48, finate: true, listener: nil)
        playbackBuffer = engine?.start()
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        engine?.stop()
    }
    
    func test01ScheduleEmpty_Nil()  {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 0)!
        guard let nodeNow = playbackBuffer?.scheduling.nodeNow else { XCTFail(); return }
        print("\(nodeNow.sampleTime)")
        let took = schedule(buffer, at: nil)
        print ( "scheduled nil took \(took*1000) ms" )
    }
    
    
    func test02ScheduleEmpty_MultipleNil() throws {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 0)!
        let took = schedule(buffer, at: nil)
        print ( "0. scheduled nil took \(took*1000) ms" )
        
        for i in (1...5) {
            let took = schedule(buffer, at: nil)
            print ( "\(i). scheduled nil took \(took*1000) ms" )
        }
    }
    
    
    func test10ScheduleEmpty_Started() throws {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 0)!
        guard let started = playbackBuffer?.scheduling.playerNow else { XCTFail(); return }
        let took = schedule(buffer, at: started)
        print ( "scheduled node now took \(took*1000) ms" )
    }
    
    func test12ScheduleEmpty_StartedPlusOne()  {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 0)!
        guard let started = playbackBuffer?.scheduling.playerNow else { XCTFail(); return }
          print("\(started.sampleTime)")
        guard let inOneSecond = playbackBuffer?.scheduling.calc(started, add: oneSec) else { XCTFail(); return }
        let took = schedule(buffer, at: inOneSecond)
        print ( "scheduled \(inOneSecond.sampleTime) took \(took*1000) ms" )
    }
    
    func test13ScheduleEmpty_NodeInPast_Nil()  {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 0)!
        guard let nodeNow = playbackBuffer?.scheduling.playerNow else { XCTFail(); return }
          print("\(nodeNow.sampleTime)")
        let changedNow = playbackBuffer?.scheduling.calc(nodeNow, sub: 3*oneSec)
        var took = schedule(buffer, at: changedNow)
        print ( "1. scheduled \(changedNow!.sampleTime) took \(took*1000) ms" )
        took = schedule(buffer, at: nil)
        print ( "2. scheduled nil took \(took*1000) ms" )
    }

    func test15ScheduleEmpty_MutlipleStarted() throws {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 0)!
        for i in (0...5) {
            guard let started = playbackBuffer?.scheduling.playerNow else { XCTFail(); return }
            let took = schedule(buffer, at: started)
            print ( "\(i). scheduled node now took \(took.magnitude * 1000) ms" )
        }
    }
        
    func test17ScheduleEmpty_StartedMultipleNext() throws {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 0)!
        guard let started = playbackBuffer?.scheduling.playerNow else { XCTFail(); return }
        
        let took = schedule(buffer, at: started)
        print ( "0. scheduled empty node now took \(took.magnitude * 1000) ms" )
        
        var nodeNext = AVAudioTime(sampleTime: started.sampleTime + oneSec/4, atRate: format.sampleRate )
        
        for i in (1...5) {
            let took = schedule(buffer, at: nodeNext)
            print ( "\(i). scheduled empty node next took \(took.magnitude * 1000) ms" )
            nodeNext = AVAudioTime(sampleTime: nodeNext.sampleTime + oneSec/4, atRate: format.sampleRate )
        }
    }
        
    func test30ScheduleShort_Nil() throws {
        let frames = AVAudioFrameCount(Int64(oneSec/4))
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let took = schedule(buffer, at: nil)
        print ( "scheduled short nil took \(took * 1000) ms" )
    }
        
    func test31ScheduleShort_MultipleNil() throws {
        let frames = AVAudioFrameCount(Int64(oneSec/4))
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let took = schedule(buffer, at: nil)
        print ( "0. scheduled short nil took \(took * 1000) ms" )
        for i in (0...5) {
            let took = schedule(buffer, at: nil)
            print ( "\(i). scheduled short nil took \(took * 1000) ms" )
        }
    }
        
    func test32ScheduleShort_Started() throws {
        let frames = AVAudioFrameCount(Int64(oneSec/4))
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        guard let started = playbackBuffer?.scheduling.playerNow else { XCTFail(); return }
        let took = schedule(buffer, at: started)
        print ( "scheduled short node now took \(took * 1000) ms" )
    }
    
    func test33ScheduleShort_MutlipleStarted() throws {
        let frames = AVAudioFrameCount(Int64(oneSec/4))
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for i in (0...5) {
            guard let started = playbackBuffer?.scheduling.playerNow else { XCTFail(); return }
            let took = schedule(buffer, at: started)
            print ( "\(i). scheduled short node now took \(took.magnitude * 1000) ms" )
        }
    }
        
    func test34ScheduleShort_StartedMultipleNext() throws {
        let frames = AVAudioFrameCount(oneSec/4)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        guard let started = playbackBuffer?.scheduling.playerNow else { XCTFail(); return }
        
        let took = schedule(buffer, at: started)
        print ( "0. scheduled short node now took \(took * 1000) ms" )
        
        var nodeNext = AVAudioTime(sampleTime: started.sampleTime + oneSec/4, atRate: format.sampleRate )
        for i in (1...5) {
            let took = schedule(buffer, at: nodeNext)
            print ( "\(i). scheduled short node next took \(took * 1000) ms" )
            nodeNext = AVAudioTime(sampleTime: nodeNext.sampleTime + oneSec/4, atRate: format.sampleRate )
        }
    }



    fileprivate func schedule(_ buffer:AVAudioPCMBuffer, at:AVAudioTime?) -> TimeInterval {
        let wait = Wait()
        guard let took = wait.exec( { self.playbackBuffer?.scheduling.playerNode.scheduleBuffer(buffer, at: at, options: [], completionCallbackType: AVAudioPlayerNodeCompletionCallbackType.dataConsumed, completionHandler: { (completion:AVAudioPlayerNodeCompletionCallbackType?) -> () in wait.thx() } )
        } ).go(3, 0.001) else {
            XCTFail("scheduling didn't complete within 3 s")
            return TimeInterval()
        }
        return took
    }
}

class Wait {
    
    var wait:Bool?
    var exec : (() -> Void)?
    var instructing:Date?
    var took:TimeInterval?
    init() {
    }
    func exec(_ exec: @escaping () -> Void ) -> Wait{
        self.exec = exec
        return self
    }
    let concurrentQueue = DispatchQueue(label: "io.ybrid.playing.wait")
    func go(_ maxS: Int, _ every:TimeInterval) -> TimeInterval? {
        wait = true
        let maxUs = UInt32(maxS*1000000)
        let everyUs = UInt32(every*1000000)
        
        if let exec = self.exec {
            instructing = Date()
            concurrentQueue.async {
                exec()
            }
        }
        var i = UInt32(0)
        var tickS = UInt32(0)
        while self.wait! && i < maxUs {
            if tickS > 1000000 {
                tickS -= 1000000
                print(".", terminator: "")
            }
            usleep(everyUs)
            i += everyUs
            tickS += everyUs
            
        }
        print("\(i)/\(self.wait!)")
        return took
    }
    func thx() {
        took = Date().timeIntervalSince(instructing!)
        wait = false
    }
    
}
