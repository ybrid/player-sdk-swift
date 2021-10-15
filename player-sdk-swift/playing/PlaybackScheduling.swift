//
// PlaybackScheduling.swift
// player-sdk-swift
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

import AVFoundation

class PlaybackScheduling {
    
    let playerNode:AVAudioPlayerNode // visible for tests
    let sampleRate:Double // visible for buffer
    var firstScheduled:AVAudioTime?
    private var nextScheduleTime:AVAudioTime?
    private var totalScheduled:TimeInterval = 0.0
    
    var nodeNow:AVAudioTime? {
        guard let lastSample = playerNode.lastRenderTime  else {
            return nil
        }
        return lastSample
    }
    
    var playerNow:AVAudioTime? {
        guard let nodeNow = nodeNow else {
            return nil
        }
        return playerNode.playerTime(forNodeTime: nodeNow)
    }
    
    var audioSince:TimeInterval? {
        guard let playerNow = playerNow else {
            return nil
        }
        guard let audioStarted = firstScheduled else {
            return nil
        }
        return diff(audioStarted, playerNow)
    }
    
    var lastRemaining:TimeInterval?
    var remainingS:TimeInterval? {
        guard let since = audioSince else {
            return lastRemaining
        }
        var result = totalScheduled - since
        if result <= 0.0  {
            result = 0.0
        }
        lastRemaining = result
        return result
    }

    
     init(_ playerNode:AVAudioPlayerNode, sampleRate: Double) {
        self.playerNode = playerNode
        self.sampleRate = sampleRate
    }
    
    deinit {
        Logger.playing.debug()
    }
    
    func reset() {
        nextScheduleTime = nil
        totalScheduled = 0.0
        firstScheduled = nil
    }
    
    func schedule(chunk:PlaybackBuffer.Chunk) {
         guard let now = playerNow else {
            Logger.playing.debug(String(format: "isn't running, ignoring %3.0f ms", chunk.duration*1000))
            return
        }
        
        let scheduleTime:AVAudioTime
        if firstScheduled == nil {
            firstScheduled = now
            Logger.playing.debug("first scheduling at \(describe(firstScheduled)) ms")
            scheduleTime = now
        } else {
            guard let nextTime = nextScheduleTime else {
                Logger.playing.error(String(format: "next scheduling time missing, ignoring chunc of %3.0f ms", chunk.duration*1000))
                return
            }
            scheduleTime = nextTime
        }
        nextScheduleTime = calc(scheduleTime, add: Int64(chunk.pcm.frameLength))
        if Logger.verbose { Logger.playing.debug(String(format: "schedules %3.0f ms at %@ --> next at %@", chunk.duration*1000, describe(scheduleTime), describe(nextScheduleTime))) }
        
        playerNode.scheduleBuffer(chunk.pcm, at: scheduleTime, options: [])
        totalScheduled += chunk.duration
     }
    
     func calc(_ time:AVAudioTime, add:Int64) -> AVAudioTime {
        let calcTime = AVAudioTime(sampleTime: time.sampleTime + add, atRate: sampleRate)
        if time.isHostTimeValid {
            return calcTime.extrapolateTime(fromAnchor: time)!
        }
        return calcTime
    }
    
    func calc(_ time:AVAudioTime, sub:Int64) -> AVAudioTime {
        let calcTime = AVAudioTime(sampleTime: time.sampleTime - sub, atRate: sampleRate )
        if time.isHostTimeValid {
            return calcTime.extrapolateTime(fromAnchor: time)!
        }
        return calcTime
    }
    
    private func diff(_ from:AVAudioTime, _ to:AVAudioTime) -> TimeInterval {
        
        return TimeInterval( Double(to.sampleTime - from.sampleTime) / sampleRate)
    }
    
    private func describe(_ time: AVAudioTime?) -> String {
        guard let time = time else {
            return "(no time)"
        }
        if time.isSampleTimeValid {
            return String(format: "%0.3f s", Double(time.sampleTime) / sampleRate )
        }
        if time.isHostTimeValid {
            return String(format: "hostTime %0.6f s", Double(time.hostTime) / 1000000000)
        }
        return "(no valid time)"
    }
}
