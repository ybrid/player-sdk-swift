//
// PlaybackBuffer.swift
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

protocol BufferListener: class {
    func stateChanged(_ bufferState: PlaybackBuffer.BufferState)
}

class PlaybackBuffer {
    
    private static let preBufferingS = 0.5
    private static let reBufferingS = 1.5
    private static let lowRemainingScheduledS = 0.6
    private static let healScheduledS = 0.5
    
    enum BufferState {
        case empty
        case ready
        case wait
    }
    private var state:BufferState = .empty {
        didSet {
            if state != oldValue {
                Logger.playing.debug("buffer state is \(state)")
                listener?.stateChanged(state)
                switch state {
                case .ready: audioOn()
                case .empty: audioOff()
                case .wait: audioOff()
                }
            }
        }
    }
    private func audioOn() {
        Logger.playing.notice()
        engine.change(volume: 1)
    }
    private func audioOff() {
        Logger.playing.notice()
        engine.change(volume: 0)
    }
    
    var isEmpty:Bool { get {
        return state == .empty
    }}
    
    var playingSince: TimeInterval? {
        return scheduler.audioSince
    }
    
    private let buffer:ChunkedBuffer
    var scheduler:PlaybackScheduler /// visible for unit tests

    let engine: PlaybackEngine
    private var thresholdS:TimeInterval
    weak var listener:BufferListener?

    private var buffering:TimeInterval { get {
        return buffer.duration
    }}
    private var remaining:TimeInterval { get {
        return scheduler.remainingS ?? 0.0
    }}

    var onMetadataCue:((UUID)->())?
    
    init(scheduling:PlaybackScheduler, engine: PlaybackEngine) {
        self.buffer = ChunkedBuffer()
        self.scheduler = scheduling
        self.engine = engine
        self.thresholdS = PlaybackBuffer.preBufferingS
    }
    
    deinit {
        Logger.playing.debug()
    }
    
    func dispose() {
        Logger.playing.debug("pre deinit")
        if let disposedS = buffer.clear() {
            Logger.playing.debug("disposed \(disposedS.S) of buffered audio")
        }
    }
    
    func put(pcmBuffer: AVAudioPCMBuffer) {
        let bufferDuration = Double(AVAudioFramePosition(pcmBuffer.frameLength)) / scheduler.sampleRate
        let chunk = Chunk(pcm: pcmBuffer, duration: bufferDuration)
        
        buffer.put(chunk: chunk)
        if Logger.verbose { Logger.playing.debug("buffered \(chunk.duration.S)") }
        
        ensurePlayback()
    }
    
    static let emptyPcm = AVAudioPCMBuffer()
    func put(cuePoint:UUID) {
        let chunk = Chunk(pcm: PlaybackBuffer.emptyPcm, duration: 0, cuePoint: cuePoint)
        buffer.put(chunk: chunk)
        
        if Logger.verbose { Logger.playing.debug("metadata cue point --> \(cuePoint)") }
    }
    
    func put(_ cueAudioComplete: @escaping AudioCompleteCallback) {
        let chunk = Chunk(pcm: PlaybackBuffer.emptyPcm, duration: 0, cueAudioComplete: cueAudioComplete)
        buffer.put(chunk: chunk)
        
        Logger.playing.debug("audio complete cue point --> \(String(describing: cueAudioComplete))")
    }
    
    // REVIEW pause and resume should net set calculated state
    func pause() {
        state = .wait
    }
    
    func resume() {
        state = .ready
    }
    
    func update() -> TimeInterval {
        ensurePlayback()
        return buffering + remaining
    }
    
    func reset() {
        if let cleared = buffer.clear() {
            Logger.playing.notice("discarded \(cleared.S) s of buffered audio")
            return
        }
    }
    
    func endOfStream() {
        Logger.playing.debug()
        thresholdS = 0.0
        /// scheduler needs no eos signalling
    }
    
    private class BufferInstant {
        private let buffered:TimeInterval
        private let threshold:TimeInterval
        private let scheduled:TimeInterval
        init(_ buffered:TimeInterval, _ threshold:TimeInterval, _ scheduled:TimeInterval) {
            self.buffered = buffered
            self.threshold = threshold
            self.scheduled = scheduled
        }
        
        var drained:Bool { get {
            return buffered + scheduled <= 0.0
        } }
        var sufficient:Bool { get {
            return scheduled <= 0.0 && buffered >= threshold
        } }
        var lowScheduling: Bool { get {
            return scheduled > 0.0 && scheduled <= PlaybackBuffer.lowRemainingScheduledS
        } }
        
        var description:String { get {
            return "\((buffered + scheduled).S) ( buffering \(buffered.S), remainig \(scheduled.S) ), threshold \(threshold.S)"
        } }
    }

    
    private func ensurePlayback() {
        guard state != .wait else {
            return
        }
        
        let instant = BufferInstant(buffering, thresholdS, remaining)
        if Logger.verbose { Logger.playing.debug("buffer is \(instant.description)") }
        
        if state == .empty && instant.sufficient  { // needs scheduling first chunks
            if let scheduled = schedule(expectS: PlaybackBuffer.healScheduledS) {
                if Logger.verbose { Logger.playing.debug("scheduled first \(scheduled.S)") }
                state = .ready
            }
            return
        }

        if state == .ready && instant.lowScheduling { // needs scheduling next chunks
            if let scheduled = schedule(expectS: PlaybackBuffer.healScheduledS) {
                if Logger.verbose { Logger.playing.debug("scheduled next \(scheduled.S)") }
            }
            return
        }
   
        if state == .ready && instant.drained {
            state = .empty
            scheduler.reset()
            thresholdS = PlaybackBuffer.reBufferingS
            return
        }
 
        if Logger.verbose { Logger.playing.debug("nothing to do") }
        return
    }
    
    private func schedule(expectS:TimeInterval) -> TimeInterval? {
        var scheduled:TimeInterval = 0.0
        repeat {
            guard let duration = scheduleNext() else {
                if scheduled > 0.0 {
                    return scheduled
                }
                return nil
            }
            scheduled += duration
        } while scheduled < expectS
        guard scheduled > 0.0 else { return nil }
        return scheduled
    }
    
    private func scheduleNext() -> TimeInterval? {
        guard let takenChunk = buffer.pop() else {
            return nil
        }
        if let cue = takenChunk.cuePoint {
            DispatchQueue.global().asyncAfter(deadline: .now() + remaining) {
                self.onMetadataCue?(cue)
            }
            return 0.0
        }
        if let complete = takenChunk.cueAudioComplete {
            DispatchQueue.global().asyncAfter(deadline: .now() + remaining) {
                complete(true)
            }
            return 0.0
        }
        self.scheduler.schedule(chunk: takenChunk)
        return takenChunk.duration
    }
    
    // MARK: buffering pcm audio chunks

    struct Chunk {
        let pcm:AVAudioPCMBuffer
        let duration:TimeInterval
        var cuePoint:UUID? = nil
        var cueAudioComplete:AudioCompleteCallback? = nil
    }
    
    private class ChunkedBuffer : ThreadsafeDequeue<Chunk> {
        
        init() {
            let queue = DispatchQueue(label: "io.ybrid.playing.chunks", qos: PlayerContext.processingPriority)
            super.init(queue)
        }
        
        var duration:TimeInterval {
            guard super.count > 0 else {
                return 0.0
            }
            return super.all.map { $0.duration }.reduce(0.0, +)
        }
       
        func put(chunk:Chunk) {
            super.put(chunk)
        }

        func clear() -> TimeInterval? {
            let cleared = duration
            
            super.all.forEach{ (chunk) in
                if let complete = chunk.cueAudioComplete {
                    complete(true)
                }
            }
            super.clear()
            guard cleared > 0.0 else { return nil }
            return cleared
        }
    }
}

extension TimeInterval {
    var S:String {
        return String(format: "%.3f s", self)
    }
}
