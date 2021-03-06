//
// AudioPipeline.swift
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
 
protocol PipelineListener: class {
    func ready(playback: Playback)
    func notify(_ severity:ErrorSeverity, _ error: AudioPlayerError)
}

protocol MetadataListener: class {
    func metadataReady(_ metadata: AbstractMetadata)
}

class AudioPipeline : DecoderListener, MemoryListener, MetadataListener {
    
    let pipelineListener: PipelineListener
    var started = Date()
    var resumed = false
    var firstPCM = true
    var firstMetadata = true
    var stopping = false
    var changeOver:AudioCompleteCallback? = nil { didSet {
        metadataExtractor?.lastMetadataHash = nil
    }}

    var icyFields:[String:String]? { didSet {
        Logger.loading.notice("icy fields \(icyFields ?? [:])")
    }}

    var bufferSize:TimeInterval? { get {
        return buffer?.size
    }}

    private var metadataExtractor: MetadataExtractor?
    private var accumulator: DataAccumulator?
    private var decoder: AudioDecoder?
    private var buffer: PlaybackBuffer?
    var infinite: Bool = true // default live
    
    weak var playerListener:AudioPlayerListener?
    let session:MediaSession

    let decodingQueue = DispatchQueue(label: "io.ybrid.decoding", qos: PlayerContext.processingPriority)
    let metadataQueue = DispatchQueue(label: "io.ybrid.metadata", qos: PlayerContext.processingPriority)
    
    init(pipelineListener: PipelineListener, playerListener: AudioPlayerListener?, session: MediaSession) {
        self.pipelineListener = pipelineListener
        self.playerListener = playerListener
        self.session = session
        /// not calling asynchrounously: If the session needs to be reconnected, the audio data loader uses the updated playbackUri coming from the session.
        if let metadata = self.session.fetchMetadataSync() {
            self.notifyMetadataChanged(metadata)
        }
        PlayerContext.registerMemoryListener(listener: self)
    }
    
    deinit {
        Logger.decoding.debug()
    }
    
    func stopProcessing() {
        stopping = true
        decoder?.stopping = true
    }
    
    func dispose() {
        Logger.decoding.debug("pre deinit")
        _ = self.accumulator?.reset()
        self.decoder?.dispose()
        self.buffer?.dispose()
        PlayerContext.unregisterMemoryListener(listener: self)
    }
    
    func reset() {
        started = Date()
        firstPCM = true
        firstMetadata = true
        resumed = true
        metadataQueue.async {
            self.session.refresh()
        }
    }
    
    // MARK: setup pipeline
    
    func prepareMetadata(metadataInverallB: Int) {
        self.metadataExtractor = MetadataExtractor(bytesBetweenMetadata: metadataInverallB, listener: self)
    }
        
    func prepareAudio(audioContentType: AudioFileTypeID) throws {
        
        // deactivated until we destinguish between icecast and ybrid
//        self.accumulator = DataAccumulator(type: audioContentType)
        
        switch audioContentType {
        case kAudioFormatOpus:
            let ogg = try OggContainer()
            self.decoder = try OpusDecoder(container: ogg, decodingListener: self)
        default:
            self.decoder = try MpegDecoder(audioContentType: audioContentType, decodingListener: self)
        }
    }
    
    func setInfinite(_ infinite: Bool) {
        self.infinite = infinite
    }
    
    // MARK: handle memory
    
    func notifyExceedsMemoryLimit() {
        Logger.loading.notice("stop audio processing due to memory limit")
        pipelineListener.notify(ErrorSeverity.recoverable, AudioPlayerError(.memoryLimitExceeded, "audio truncated"))
        stopProcessing()
    }
    
    // MARK: "main" is to process data chunks
    
    func process(data: Data) {

        let treatedData = treatMetadata(data: data)
        
        let accuData = accumulate( treatedData ?? data )
        
        guard let audioData = accuData else {
            return
        }

        self.decode(data: audioData)

    }
    
    func flushAudio() {
        Logger.decoding.debug()
        if let audioData = accumulator?.reset() {
            self.decode(data: audioData)
        }
    }

    
    // MARK: decoder listener
    
    func onFormatChanged(_ sourceFormat:AVAudioFormat) -> () {
        
        do {
            if let pcmTargetFormat = try decoder?.create(from: sourceFormat) {
                if self.buffer == nil {
                    let engine = PlaybackEngine(format: pcmTargetFormat, listener: playerListener )
                    if !infinite { engine.canPause = true }
                    self.buffer = engine.start()
                    self.pipelineListener.ready(playback: engine)
                }
            }
            if resumed {
                buffer?.reset()
                resumed = false
            }
        } catch {
            Logger.decoding.error(error.localizedDescription)
            if let audioDataError = error as? AudioPlayerError {
                pipelineListener.notify(ErrorSeverity.fatal, audioDataError)
            } else {
                pipelineListener.notify(ErrorSeverity.fatal, AudioDataError(ErrorKind.unknown, "problem with audio format", error))
            }
            return
        }
    }
    
    func pcmReady(pcmBuffer:AVAudioPCMBuffer) -> () {
        guard !self.stopping else {
            Logger.decoding.debug("stopping pipeline, ignoring pcm data")
            return
        }
        
        buffer?.put(buffer: pcmBuffer)
        
        if firstPCM {
            firstPCM = false
            DispatchQueue.global().async {
                self.playerListener?.durationReadyToPlay(Date().timeIntervalSince(self.started))
            }
        }
    }
    
    // MARK: metadata listener
    
    func metadataReady(_ metadata: AbstractMetadata) {
        
        if let broadcaster = icyFields?["icy-name"] {
            metadata.setBroadcaster(broadcaster)
        }
        if let genre = icyFields?["icy-genre"] {
            metadata.setGenre(genre)
        }
        
        let durationUntilPresenting = bufferSize
        if let changeOverCallback = changeOver {
            changeOver = nil
            if let delayBy = durationUntilPresenting {
                DispatchQueue.global().asyncAfter(deadline: .now() + delayBy) {
                    changeOverCallback(true)
                }
            } else {
                DispatchQueue.global().async {
                    changeOverCallback(true)
                }
            }
        }
        
        if firstMetadata {
            firstMetadata = false
            var newMetadata = metadata
            metadataQueue.async {
                if let metadata = self.session.fetchMetadataSync() {
                    newMetadata = metadata
                }
                self.notifyMetadataChanged(newMetadata)
            }
            return
        }
        if let delayBy = durationUntilPresenting {
            let metadataId = session.maintainMetadata(metadata: metadata)
            metadataQueue.asyncAfter(deadline: .now() + delayBy) {
                if let delayedMd = self.session.popMetadata(uuid: metadataId) {
                    self.notifyMetadataChanged(delayedMd)
                }
            }
        }
    }
    
    // MARK: processing steps
    
    private func treatMetadata(data: Data) -> Data? {
        guard let mdExtractor = metadataExtractor else {
            return nil
        }
        let treatedData = mdExtractor.handle(payload: data)
        if Logger.verbose { Logger.decoding.debug("\(data.count - treatedData.count) of \(data.count) bytes were extracted") }
        
        return treatedData
    }
    
    private func accumulate(_ data:Data) -> Data? {
        guard let accu = accumulator else {
            return data
        }
        return accu.chunk(data)
    }
    
    private func decode(data: Data) {
        guard !self.stopping else {
            Logger.decoding.debug("stopping pipeline, ignoring data")
            return
        }
        decodingQueue.async {
            guard let decoder = self.decoder else {
                if Logger.verbose { Logger.decoding.debug("no decoder avaliable") }
                return
            }
            
            do {
                try decoder.decode(data: data)
                return
            } catch {
                guard !self.stopping else {
                    Logger.decoding.notice("stopping pipeline, ignoring decoding error")
                    return
                }
                Logger.decoding.error(error.localizedDescription)
                if let playerError = error as? AudioPlayerError {
                    self.pipelineListener.notify(ErrorSeverity.fatal, playerError)
                } else {
                    self.pipelineListener.notify(ErrorSeverity.fatal, AudioDataError(ErrorKind.unknown, "cannot convert audio data", error))
                }
            }
        }
    }
    
    fileprivate func notifyMetadataChanged(_ metadata:Metadata) {
        guard !self.stopping else {
            Logger.decoding.debug("stopping pipeline, ignoring metadata")
            return
        }
        guard let _ = metadata.displayTitle else {
            Logger.decoding.notice("no metadata to notifiy")
            return
        }
        DispatchQueue.global().async {
            self.playerListener?.metadataChanged(metadata)
        }
    }
    
    ///  delegate for visibility
    static func describeFormat(_ format: AVAudioFormat) -> String {
        return describe(format: format)
    }
}

fileprivate func describe(format: AVAudioFormat?) -> String {
    guard let fmt = format else {
        return String(format:"(no format information)")
    }
    let desc = fmt.streamDescription.pointee
    
    return String(format: "audio %@ %d ch %.0f Hz %@ %@", AudioData.describeFormatId(desc.mFormatID) , desc.mChannelsPerFrame, desc.mSampleRate, AudioData.describeBitdepth(format?.commonFormat), fmt.isInterleaved ? "interleaved" : "non interleaved" )
}
