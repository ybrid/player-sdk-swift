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
                Logger.playing.debug("\(state)")
                listener?.stateChanged(state)
                switch state {
                case .ready: audioOn()
                case .empty: audioOff()
                case .wait: audioOff()
                }
            }
        }
    }

    var playingSince: TimeInterval? {
        return scheduling.audioSince
    }
    
    var size: TimeInterval? {
        refreshSize()
        return total
    }
    
    private let cachedChunks:ChunkCache
    let scheduling:PlaybackScheduling /// visible for unit tests
    
    weak var listener:BufferListener?
    let engine: PlaybackEngine
    
    private var bufferingS:TimeInterval = preBufferingS

    private var caching:TimeInterval = 0.0
    private var remaining:TimeInterval = 0.0
    private var total:TimeInterval { get { return caching + remaining } }
    private var bufferDescription:String { get {
        return "buffer size \(total.S) ( caching \(caching.S), remainig \(remaining.S) )"
    } }

    
    init(scheduling:PlaybackScheduling, engine: PlaybackEngine) {
        self.cachedChunks = ChunkCache()
        self.scheduling = scheduling
        self.engine = engine
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
        caching += chunk.duration
        
        if Logger.verbose { Logger.playing.debug("cached \(chunk.duration.S) --> \(bufferDescription)") }
        
        takeCare()
    }
    
    func pause() {
        state = .wait
    }
    
    func resume() {
        state = .ready
    }

    func update() -> TimeInterval {
        refreshSize()
        takeCare()
        return total
    }
    
    func reset() {
        if let cleared = cachedChunks.clear() {
            Logger.playing.notice("discarded \(cleared.S) s of cached audio")
            refreshSize()
            return
        }
    }
    
    private var isEmpty:Bool { get { return total <= 0.0 } }
    private var isBufferingDone:Bool { return remaining <= 0.0 && caching >= bufferingS }
    private var isSchedulingLow: Bool { return remaining > 0.0 && remaining <= PlaybackBuffer.lowRemainingScheduledS }
    
    fileprivate func refreshSize() {
        caching = cachedChunks.duration
        remaining = scheduling.remainingS ?? 0.0
    }
    
    fileprivate func takeCare() {
        guard state != .wait else {
            return
        }
        
        if Logger.verbose { Logger.playing.debug("\(bufferDescription)") }
        
        if isEmpty {
            state = .empty
            scheduling.reset()
            bufferingS = PlaybackBuffer.reBufferingS
            return
        }
        
        if isBufferingDone  { // needs scheduling first chunks
            if let scheduled = schedule(expectS: PlaybackBuffer.healScheduledS) {
                if Logger.verbose { Logger.playing.debug("scheduled first \(scheduled.S) --> \(bufferDescription)") }
                state = .ready
            }
            return
        }

        if isSchedulingLow { // needs scheduling next chunks
            if let scheduled = schedule(expectS: PlaybackBuffer.healScheduledS) {
                if Logger.verbose {
                    Logger.playing.debug("scheduled next \(scheduled.S) --> \(bufferDescription)") }
            }
        }
        
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
        self.scheduling.schedule(chunk: takenChunk)
        let scheduled = takenChunk.duration
        caching -= scheduled
        remaining += scheduled
        return scheduled
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
            super.clear()
            guard cleared > 0.0 else { return nil }
            return cleared
        }
    }

//    class ThreadsafeDequeue<T> {
//
//
//        private var element = [T]()
//        var count:Int {queue.sync { element.count } }
//        var all:[T] { queue.sync { return element } }
//        func put(_ package: T) { queue.async { self.element.append(package) } }
//        func take() -> T? {
//            queue.sync {
//                guard self.element.count > 0 else { return nil }
//                return self.element.removeFirst()
//            }
//        }
//        func clear() { queue.async { self.element.removeAll() } }
//    }
}

extension TimeInterval {
    var S:String {
        return String(format: "%.3f s", self)
    }
}
