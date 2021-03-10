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
    func error(_ level: ErrorLevel, _ component: ErrorComponent, _ kind: ErrorKind, _ message:String)
}

enum ErrorLevel {
    case fatal
    case recoverable
    case notice
}

enum ErrorComponent {
    case loading
    case decoding
    case playing
}

typealias ErrorCode = Int
enum ErrorKind : ErrorCode {
    case noError = 0
    case unknown = 100
    
    // loading, reding from network, using core foundation codes
    case timedOutLoadingData = -1001
    case unsuportedUrl = -1002
    case hostNotFound = -1003
    case connectionLost = -1005
    case offline = -1009
    case noHttps = -1022
    case cannotConnectOverSsl = -1200
    case lostConnectionToBackgroudTransferService = -997
    
    // loading, reading http
    case missingMimeType = 300
    case cannotProcessMimeType = 301

    // decoding, audio data
    case cannotOpenStream = 411
    case parsingFailed = 412
    case notSupported = 413

    // decoding, decoder
    case missingSourceFormat = 521
    case missingTargetFormat = 522
    case cannotCreateConverter = 523
    case missingDataSource = 524
    case failedPackaging = 525
    case failedToAllocatePCMBuffer = 526
    case failedConverting = 527
    case invalidData = 528
}


class AudioPipeline : DecoderListener
{
    let pipelineListener: PipelineListener
    var started = Date()
    var resumed = false
    var firstPCM = true
    var firstMetadata = true
    var stopping = false
    private var metadataExtractor: MetadataExtractor?
    private var accumulator: DataAccumulator?
    private var decoder: AudioDecoder?
    private var buffer: PlaybackBuffer?
    
    private var icyUrl: String?
//        {
//            didSet {
//                Logger.loading.notice("\(icyUrl)")
//            }
//        }
    
    weak var playerListener:AudioPlayerListener?
    let decodingQueue = DispatchQueue(label: "io.ybrid.decoding", qos: PlayerContext.processingPriority)
    let metadataQueue = DispatchQueue(label: "io.ybrid.metadata", qos: PlayerContext.processingPriority)
    
    
    init(pipelineListener: PipelineListener, playerListener: AudioPlayerListener?) {
        self.pipelineListener = pipelineListener
        self.playerListener = playerListener
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
    }
    
    func resume() {
        started = Date()
        firstPCM = true
        firstMetadata = true
        resumed = true
    }
    
    func prepareMetadata(metadataInverallB: Int) {
        self.metadataExtractor = MetadataExtractor(bytesBetweenMetadata: metadataInverallB)
    }
    
    func prepareAudio(audioContentType: AudioFileTypeID) {
        
        self.accumulator = DataAccumulator(type: audioContentType)
        
        do {
            switch audioContentType {

            case kAudioFormatOpus:
                let ogg = try OggContainer(delegate: playerListener)
                decoder = try OpusDecoder(container: ogg, decodingListener: self)

            default:
                decoder = try MpegDecoder(audioContentType: audioContentType, decodingListener: self)
            }
        } catch  {
            Logger.decoding.error("cannot read data source, reason \(error.localizedDescription)")
            if let audioDataError = error as? AudioDataError {
                pipelineListener.error(ErrorLevel.fatal, ErrorComponent.decoding, audioDataError.kind,  audioDataError.message ?? error.localizedDescription)
            } else {
                pipelineListener.error(ErrorLevel.fatal, ErrorComponent.decoding, ErrorKind.unknown, "cannot read data source")
            }
            return
        }

    }
    
    // MARK: decoder listener
    
    func onFormatChanged(_ sourceFormat:AVAudioFormat) -> () {
        
        do {
            if let pcmTargetFormat = try decoder?.create(from: sourceFormat) {
                if self.buffer == nil {
                    let engine = PlaybackEngine(format: pcmTargetFormat, listener: self.playerListener )
                    self.buffer = engine.start()
                    self.pipelineListener.ready(playback: engine)
                }
            }
            if resumed {
                buffer?.resume()
                resumed = false
            }
        } catch {
            Logger.decoding.error(error.localizedDescription)
            if let audioDataError = error as? AudioDataError {
                pipelineListener.error(ErrorLevel.fatal, ErrorComponent.decoding, audioDataError.kind, audioDataError.message ?? "problem with audio format")
            } else {
                pipelineListener.error(ErrorLevel.fatal, ErrorComponent.decoding, ErrorKind.unknown, "problem with audio format")
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
            playerListener?.durationReadyToPlay(Date().timeIntervalSince(self.started))
        }
    }
    
    func metadataReady(_ metadata: Metadata) {
        if firstMetadata {
            firstMetadata = false
            notifyMetadataChanged(metadata)
            return
        }
        
        if let timeToMetadataPlaying = buffer?.size {
            metadataQueue.asyncAfter(deadline: .now() + timeToMetadataPlaying) {
                self.notifyMetadataChanged(metadata)
            }
        }

    }
    
    // MARK: "main" method
    
    func process(data: Data) {
        
        let treatedData = treatMetadata(data: data)
        
        let accuData = accumulate( treatedData ?? data )
        
        guard let audioData = accuData else {
            return
        }

        self.decode(data: audioData)
    }
    
    func flushAudio() {
        if let audioData = accumulator?.reset() {
            self.decode(data: audioData)
        }
    }

    
    // MARK: processing steps
    
    private func treatMetadata(data: Data) -> Data? {
        guard let mdExtractor = metadataExtractor else {
            return nil
        }
        let treatedData = mdExtractor.handle(payload: data, metadataCallback: { (metadata:[String:String]) in
            Logger.decoding.debug("extracted metadata is \(metadata)")
            if let streamTitle = metadata["StreamTitle"]?.trimmingCharacters(in: CharacterSet.init(charactersIn: "'")) {
                self.metadataReady(Metadata(combinedTitle: streamTitle))
            }
            let streamUrl = metadata["StreamUrl"]
            self.icyUrl = streamUrl
        })
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
                    Logger.decoding.debug("stopping pipeline, ignoring decoding error")
                    return
                }
                Logger.decoding.error(error.localizedDescription)
                if let audioDataError = error as? AudioDataError {
                    self.pipelineListener.error(ErrorLevel.fatal, ErrorComponent.decoding, audioDataError.kind, audioDataError.message ?? "cannot convert audio data")
                } else {
                    self.pipelineListener.error(ErrorLevel.fatal, ErrorComponent.decoding, ErrorKind.unknown, "cannot convert audio data")
                }
            }
        }
    }
    
    fileprivate func notifyMetadataChanged(_ metadata:Metadata) {
        guard !self.stopping else {
            Logger.decoding.debug("stopping pipeline, ignoring metadata")
            return
        }
        guard let displayTitle = metadata.displayTitle() else {
            Logger.decoding.notice("no metadata to notifiy")
            return
        }
        self.playerListener?.displayTitleChanged("\(displayTitle)")
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
