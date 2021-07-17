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
        PlayerContext.registerMemoryListener(listener: self)
        
        session.refresh()
        session.notifyMetadata()
    }
    
    deinit {
        Logger.decoding.debug()
    }
    
    func stopProcessing() {
        stopping = true
        decoder?.stopping = true
        session.changingOver?.audioComplete?(false)
        session.changingOver = nil
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
        
        session.refresh()
    }
    
    // MARK: setup pipeline
    
    func prepareMetadata(metadataInverallB: Int) {
        self.metadataExtractor = MetadataExtractor(bytesBetweenMetadata: metadataInverallB)
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

        if let mdExtractor = metadataExtractor {
            mdExtractor.dispatch(payload: data, metadataReady: metadataReady, audiodataReady: audiodataReady)
            return
        }
        
        audiodataReady(data)
    }

    
    func flushAudio() {
        Logger.decoding.debug()
        if let mdExtractor = metadataExtractor {
            mdExtractor.flush(audiodataReady)
        }
        if let audioData = accumulator?.reset() {
            self.decode(data: audioData)
        }
    }
    
    func changeOverInProgress() {
        metadataExtractor?.reset()
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
                    
                    buffer?.onMetadataCue = { (metaCueId) in
                        self.session.notifyMetadata(uuid: metaCueId)
                    }

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
    
    func audiodataReady(_ data: Data) {
        
        let accuData = accumulate( data )

        guard let audioData = accuData else {
            return
        }

        self.decode(data: audioData)
    }

    
    func metadataReady(_ metadata: AbstractMetadata) {
        guard !self.stopping else {
            Logger.decoding.debug("stopping pipeline, ignoring metadata")
            return
        }
        
        Logger.loading.debug("metadata \(metadata.displayTitle ?? "(no title)")")

        if let broadcaster = icyFields?["icy-name"] {
            metadata.setBroadcaster(broadcaster)
        }
        if let genre = icyFields?["icy-genre"] {
            metadata.setGenre(genre)
        }

        
        if firstMetadata {
            firstMetadata = false
            session.notifyMetadataSync(metadata)
        } else {
            let metadataUuid = session.maintainMetadata(metadataIn: metadata)
            buffer?.put(cuePoint: metadataUuid)
        }
        
        if let completeCallback = triggerAudioComplete(metadata) {
            
            if let _ = bufferSize {
                buffer?.put(completeCallback)
            } else {
                completeCallback(true)
            }

            session.changingOver = nil
        }
            
        // keeping values up to date
        session.notifySwapsLeft()
        session.notifyOffset()
//            session.notifyServices() /// not neccessary


    }

    
    private func triggerAudioComplete(_ metadata: AbstractMetadata) -> AudioCompleteCallback? {
        
        guard let changeOver = session.changingOver,
              let media = session.mediaControl else {
            return nil // no change over in progress or no media to work on
        }
        
        let canTrigger = (metadata as? IcyMetadata)?.streamUrl != nil
        Logger.loading.debug("\(canTrigger ?"could":"can't") trigger audio complete")
        guard canTrigger else {
            return nil
        }
        
        let type = changeOver.subInfo
        let changed = media.hasChanged(type)
        // change of data matches type of ChangeOver
        switch type {
        case .metadata:
            Logger.session.notice("change over \(type) complete")
            return changeOver.audioComplete
        case .timeshift:
             Logger.session.notice("change over \(type), offset did \(changed ? "":"not ")change")
             return changeOver.audioComplete
        case .bouquet:
            Logger.session.notice("change over \(type), active service did \(changed ? "":"not ")change")
            return changeOver.audioComplete
        default:
            Logger.session.notice("change over \(type) unexpected")
            return nil
        }
     }
    
    
    // MARK: processing steps
    
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
