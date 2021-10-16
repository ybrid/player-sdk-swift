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
    
    private static let minBufferingS = 0.1
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
    
    var isEmpty:Bool { get {
        return state == .empty
    }}
    
    var playingSince: TimeInterval? {
        return scheduling.audioSince
    }
    
    private let cachedChunks:ChunkCache
    var scheduling:PlaybackScheduling /// visible for unit tests
    
    weak var listener:BufferListener?
    let engine: PlaybackEngine
    
    private var bufferingS:TimeInterval

    private var caching:TimeInterval { get {
        return cachedChunks.duration
    }}
    private var remaining:TimeInterval { get {
        return scheduling.remainingS ?? 0.0
    }}

    var onMetadataCue:((UUID)->())?
    
    init(scheduling:PlaybackScheduling, engine: PlaybackEngine, preBuffering: Bool) {
        self.cachedChunks = ChunkCache()
        self.scheduling = scheduling
        self.engine = engine
        self.bufferingS = preBuffering ? PlaybackBuffer.preBufferingS : PlaybackBuffer.minBufferingS
    }
    
    deinit {
        Logger.playing.debug()
    }
    
    func dispose() {
        Logger.playing.debug("pre deinit")
        if let disposedS = cachedChunks.clear() {
            Logger.playing.debug("disposed \(disposedS.S) of buffered audio")
        }
    }
    
    func put(buffer: AVAudioPCMBuffer) {
        let bufferDuration = Double(AVAudioFramePosition(buffer.frameLength)) / scheduling.sampleRate
        let chunk = Chunk(pcm: buffer, duration: bufferDuration)
        
        cachedChunks.put(chunk: chunk)
        if Logger.verbose { Logger.playing.debug("cached \(chunk.duration.S)") }
        
        ensurePlayback()
    }
    
    static let emptyPcm = AVAudioPCMBuffer()
    func put(cuePoint:UUID) {
        let chunk = Chunk(pcm: PlaybackBuffer.emptyPcm, duration: 0, cuePoint: cuePoint)
        cachedChunks.put(chunk: chunk)
        
        if Logger.verbose { Logger.playing.debug("cached metadata cue point --> \(cuePoint)") }
    }
    
    func put(_ cueAudioComplete: @escaping AudioCompleteCallback) {
        let chunk = Chunk(pcm: PlaybackBuffer.emptyPcm, duration: 0, cueAudioComplete: cueAudioComplete)
        cachedChunks.put(chunk: chunk)
        
        Logger.playing.debug("cached complete cue point --> \(String(describing: cueAudioComplete))")
    }
    
    func pause() {
        state = .wait
    }
    
    func resume() {
        state = .ready
    }

    func update() -> TimeInterval {
        ensurePlayback()
        return caching + remaining
    }
    
    func reset() {
        if let cleared = cachedChunks.clear() {
            Logger.playing.notice("discarded \(cleared.S) s of cached audio")
            return
        }
    }
    
    func flush() {
        Logger.playing.debug()
        bufferingS = 0.0
    }
    
    class BufferInstant {
        private let cached:TimeInterval
        private let threshold:TimeInterval
        private let scheduled:TimeInterval
        init(_ cached:TimeInterval, _ threshold:TimeInterval, _ scheduled:TimeInterval) {
            self.cached = cached
            self.scheduled = scheduled
            self.threshold = threshold
        }
        
        var drained:Bool { get {
            return cached + scheduled <= 0.0
        } }
        var sufficient:Bool { get {
            return scheduled <= 0.0 && cached >= threshold
        } }
        var lowScheduling: Bool { get {
            return scheduled > 0.0 && scheduled <= PlaybackBuffer.lowRemainingScheduledS
        } }
        
        var description:String { get {
            return "\((cached + scheduled).S) ( caching \(cached.S), remainig \(scheduled.S) ), threshold \(threshold.S)"
        } }
    }

    
    fileprivate func ensurePlayback() {
        guard state != .wait else {
            return
        }
        
        let instant = BufferInstant(caching, bufferingS, remaining)
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
                if Logger.verbose {
                    Logger.playing.debug("scheduled next \(scheduled.S)") }
            }
            return
        }
   
        if state != .empty && instant.drained {
            state = .empty
            scheduling.reset()
            bufferingS = PlaybackBuffer.reBufferingS
            return
        }
 
        if Logger.verbose {
            Logger.playing.debug("nothing to do") }
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
        guard let takenChunk = cachedChunks.pop() else {
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
        self.scheduling.schedule(chunk: takenChunk)
        return takenChunk.duration
    }
    
    fileprivate func audioOn() {
        Logger.playing.notice()
        engine.change(volume: 1)
    }
    
    fileprivate func audioOff() {
        Logger.playing.notice()
        engine.change(volume: 0)
    }
    
     // MARK: caching pcm audio chunks

    struct Chunk {
        let pcm:AVAudioPCMBuffer
        let duration:TimeInterval
        var cuePoint:UUID? = nil
        var cueAudioComplete:AudioCompleteCallback? = nil
    }
    
    private class ChunkCache : ThreadsafeDequeue<Chunk> {
        
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
