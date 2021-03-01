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
    enum BufferState {
        case empty
        case ready
    }
    
    private var state:BufferState = .empty {
        didSet {
            if state != oldValue {
                Logger.playing.debug("\(state)")
                listener?.stateChanged(state)
            }
        }
    }
    
    var playingSince: TimeInterval? {
        return scheduling.audioSince
    }
    
    private let cachedChunks:ChunkCache
    let scheduling:PlaybackScheduling /// visible for unit tests
    fileprivate typealias bufferinfo = (caching:TimeInterval,remaining:TimeInterval)
    weak var listener:BufferListener?
    let engine: PlaybackEngine
    
    init(scheduling:PlaybackScheduling, engine: PlaybackEngine) {
        self.cachedChunks = ChunkCache(scheduling: scheduling)
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
        cachedChunks.put(chunk: chunk, audioOn: audioOn)
    }
    
    func takeCare() -> TimeInterval? {
        return cachedChunks.takeCare(audioOff: audioOff, audioOn: audioOn)
    }
    
    func resume() {
        if let cleared = cachedChunks.clear(), cleared > 0.0 {
            Logger.playing.notice("discarded \(String(format:"%.3f",cleared)) s of cached audio")
            return
        }
    }
    
    fileprivate func audioOn(bufferinfo:bufferinfo?) {

        if state == .empty {
            
            if let info = bufferinfo {
                Logger.playing.notice("buffer \((info.caching+info.remaining).S) ( caching \(info.caching.S), remainig \(info.remaining.S) )")
            } else {
                Logger.playing.notice()
            }
            
            engine.change(volume: 1)
        }
        state = .ready
    }
    
    fileprivate func audioOff(bufferinfo:bufferinfo?) {
        if state == .ready {
            if let info = bufferinfo {
                Logger.playing.notice("buffer \((info.caching+info.remaining).S) ( caching \(info.caching.S), remainig \(info.remaining.S) )")
                
                if info.remaining <= 0.0, info.caching <= 0.0 {
                    engine.change(volume: 0)
                }
                
            } else {
                Logger.playing.notice()
            }
        }
        state = .empty
    }

    
    
     // MARK: caching pcm audio chunks

    struct Chunk {
        let pcm:AVAudioPCMBuffer
        let duration:TimeInterval
    }
    private class ChunkCache : ThreadsafeDequeue<Chunk> {
        let lowRemainingScheduledS = 0.6
        let healScheduledS = 0.5
        let panicRemainingScheduledS = 0.2
        
        var bufferCachedS:TimeInterval = 0.5 // pre buffering
        
        let scheduling:PlaybackScheduling

        init(scheduling:PlaybackScheduling) {
            self.scheduling = scheduling
        }
        var duration:TimeInterval {
            guard super.count > 0 else {
                return 0
            }
            return super.all.map { $0.duration }.reduce(0.0, +)
        }
       
        func put(chunk:Chunk, audioOn: @escaping (bufferinfo?) -> () ) {
            super.put(chunk)
            let buffer = takeCare(audioOff: nil, audioOn: audioOn)
            if Logger.verbose { Logger.playing.debug("buffered after taking care \(buffer.S)") }
        }

        func takeCare(audioOff: ((bufferinfo?) -> ())?, audioOn: ((bufferinfo?) -> ()) ) -> TimeInterval {

            let cached = duration
            
            /// no audio data scheduled
            guard let remainingAudio = scheduling.remainingS else {
                /// pre buffering: cache before scheduling audio first time
                if cached > bufferCachedS {
                    if let scheduled = schedule(expectS: healScheduledS), scheduled > 0 {
                        audioOn((caching:cached-scheduled, remaining:scheduled))
                    }
                }
                return cached
            }
            
            /// no more data
            if cached <= 0.0, remainingAudio <= 0.0 {
                audioOff?((caching:cached, remaining:remainingAudio))
                scheduling.reset()
                bufferCachedS = 1.5 // some more rebuffering
                return 0.0
            }
            
            /// rebuffering: cache before scheduling audio
            if remainingAudio <= 0.0, cached > bufferCachedS {
                if let scheduled = schedule(expectS: healScheduledS), scheduled > 0 {
                    audioOn((caching:cached-scheduled, remaining:scheduled))
                }
                return cached
            }

            /// scheduling chunks necessary
            if remainingAudio > 0.0, remainingAudio <= lowRemainingScheduledS {
                if let scheduled = schedule(expectS: healScheduledS), scheduled > 0  {
                    if Logger.verbose { Logger.playing.debug("scheduled \(scheduled.S) of cached audio") }
                }
             
                if remainingAudio <= 0.0, let audioOff = audioOff {
                    audioOff((caching:cached, remaining:remainingAudio))
                }
            }
            
            return cached + remainingAudio
        }
        
        private func schedule(expectS:TimeInterval) -> TimeInterval? {
            var scheduled:TimeInterval = 0
            repeat {
                guard let duration = scheduleNext() else {
                    return scheduled
                }
                scheduled += duration
            } while scheduled < expectS
            return scheduled
        }
        
        private func scheduleNext() -> TimeInterval? {
            guard let takenChunk = take() else {
                return nil
            }
            self.scheduling.schedule(chunk: takenChunk)
            return takenChunk.duration
        }

        func clear() -> TimeInterval? {
            let cleared = duration
            super.clear()
            return cleared
        }
    }

    class ThreadsafeDequeue<T> {
        let queue = DispatchQueue(label: "de.addradio.chunks", qos: PlayerContext.processingPriority)

        private var element = [T]()
        var count:Int {queue.sync { element.count } }
        var all:[T] { queue.sync { return element } }
        func put(_ package: T) { queue.async { self.element.append(package) } }
        func take() -> T? {
            queue.sync {
                guard self.element.count > 0 else { return nil }
                return self.element.removeFirst()
            }
        }
        func clear() { queue.async { self.element.removeAll() } }
    }
}

extension TimeInterval {
    var S:String {
        return String(format: "%.3f s", self)
    }
}
