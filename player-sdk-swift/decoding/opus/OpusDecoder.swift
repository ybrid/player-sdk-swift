//
// OpusDecoder.swift
// app-example-ios
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
import YbridOpus

class OpusDecoder : AudioDecoder, OpusDataListener {
    

    private static let opusBundleIdentifier = "io.ybrid.opus-swift"
    typealias PcmSample = Float32
    fileprivate static let bytesPerSample:Int = MemoryLayout<PcmSample>.size
    
    fileprivate let container:OggContainer
    fileprivate var decoder:OpaquePointer?
    fileprivate var skipper:FrameSkipper?
    
    
    init(container: OggContainer, decodingListener: DecoderListener) throws {
        self.container = container
        try super.init(audioContentType: kAudioFormatOpus, decodingListener: decodingListener)
        container.opusListener = self
   
        if let info = Bundle(identifier: OpusDecoder.opusBundleIdentifier)?.infoDictionary {
            Logger.decoding.debug("bundle \(OpusDecoder.opusBundleIdentifier) info \(info)")
            let version = info["CFBundleShortVersionString"] ?? "(unknown)"
            let name = info["CFBundleName"] ?? "(unknown)"
            let build = info["CFBundleVersion"]  ?? "(unknown)"
            Logger.decoding.notice("using \(name) version \(version) (build \(build))")
        }
        
        let version = String(cString: opus_get_version_string())
        Logger.decoding.notice("using opus decoder \(version)")
    }
    
    deinit {
        Logger.decoding.debug()
        if decoder != nil {
            opus_decoder_destroy(decoder)
            decoder = nil
        }
    }
    
    // MARK: audio decoder
    
    override func dispose() {
        Logger.decoding.debug("pre deinit")
        container.selectedStream?.1.dispose()
        container.dispose()
        skipper = nil
    }
    
    override func create(from sourceFormat:AVAudioFormat) throws -> AVAudioFormat {
        let pcmFormat = calcPcmFormat(sourceFormat)
        self.skipper = FrameSkipper(bytesPerSample: OpusDecoder.bytesPerSample, audioBufferFactory: { (frames:Int) throws -> AVAudioPCMBuffer
            in return try self.prepareBuffer(frames: UInt32(frames))
        } )
        Logger.decoding.info("source format \(AudioPipeline.describeFormat(sourceFormat))")
        Logger.decoding.info("target format \(AudioPipeline.describeFormat(pcmFormat))")
        
        var result:opus_int32 = OPUS_OK
        decoder = opus_decoder_create(opus_int32(pcmFormat.sampleRate), opus_int32(sourceFormat.channelCount), &result)
        guard result == OPUS_OK else {
            let state = String(cString: opus_strerror(result))
            let errMsg = "cannot create opus decoder: \(state)"
            Logger.decoding.error(errMsg)
            throw DecoderError(.cannotCreateConverter, errMsg)
        }
        let size = opus_decoder_get_size(opus_int32(pcmFormat.channelCount))
        let state = String(cString: opus_strerror(result))
        Logger.decoding.debug("created opus decoder of \(size) bytes with \(state)")
        self.pcmFormat = pcmFormat
        return pcmFormat
    }
    
    func calcPcmFormat(_ sourceFormat: AVAudioFormat) -> AVAudioFormat {
        return AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sourceFormat.sampleRate, channels: sourceFormat.channelCount, interleaved: false)!
    }
    
    override func decode(data: Data) throws {
        guard !super.stopping else {
            Logger.decoding.debug("stopping, ignoring data")
            return
        }
        
        do {
            try container.parse(data: data)
        } catch {
            Logger.decoding.error("\(error.localizedDescription)")
            throw error
        }
    }

    // MARK: Opus audio data listener
    
    func preskip(preskip: Int) {
        self.skipper?.skip( frames: preskip )
    }
    
    func convert(package:AudioData.Package, granularPos:Int64?) throws {
        guard !super.stopping else {
            Logger.decoding.debug("stopping, ignore converting package")
            return
        }
        
        guard let targetFormat = pcmFormat else {
            Logger.decoding.error("target format missing")
            throw DecoderError(.missingTargetFormat)
        }
        
        do {
            var pcmSamples = try decodeToSamples(opus: package.data, channels: Int(targetFormat.channelCount))

            guard var pcmBuffer = try createPcmBuffer(pcmSamples: pcmSamples, targetFormat: targetFormat) else {
                return
            }
            pcmSamples.removeAll()
            
            try self.skipper?.execute(on: &pcmBuffer, endOfPacketFramePosition: granularPos)
            
            self.pcmReady(pcmBuffer: pcmBuffer)
            
        } catch {
            let err = DecoderError(.failedConverting)
            err.cause = error
            throw err
        }
    }

    // MARK: MetadataListener
    
    func metadataReady(_ metadata: AbstractMetadata) {
        super.listener.metadataReady(metadata)
    }
    
    // MARK: helpers
    
    func decodeToSamples(opus: Data, channels:Int) throws -> [PcmSample] {
        guard opus.count > 0 else {
            Logger.decoding.debug("\(opus.count) bytes -> empty array of samples")
            return []
        }
        
        let pcmSamples = try opus.withUnsafeBytes { (rawBody: UnsafeRawBufferPointer) throws -> [PcmSample] in
            let body:UnsafePointer<UInt8> = rawBody.bindMemory(to: UInt8.self).baseAddress!
            let opusBytes = opus.count
            guard let packagePcmFrames = try determineNAudioFrames(bytes: body, len: opusBytes) else {
                let errMsg = "cannot determine number of audio frames in package"
                Logger.decoding.error(errMsg)
                return []
            }
            if Logger.verbose { Logger.decoding.debug("decoding \(opusBytes) bytes into max \(packagePcmFrames) pcm audio frames with \(channels) channels") }
            var outInterleavedPcmData = [PcmSample](repeating:0, count:packagePcmFrames * channels)
            guard let decoder = decoder else {
                Logger.decoding.debug("no decoder")
                return []
            }
            let decodedPcmFrames = opus_decode_float(decoder, body, opus_int32(opusBytes), &outInterleavedPcmData, opus_int32(packagePcmFrames), 0) // forward error correction fec=1 necessary only for gaps
            guard decodedPcmFrames > 0 else {
                let errorState = decodedPcmFrames
                let errMsg = "opus_decode_float: error decoding \(describe(opusCode: errorState))"
                Logger.decoding.error(errMsg)
                throw DecoderError(.failedConverting, errMsg)
            }
            
            if Logger.verbose { Logger.decoding.debug("decoded \(opusBytes) bytes into \(decodedPcmFrames) pcm audio frames with \(channels) channels") }
            return outInterleavedPcmData
        }
        return pcmSamples
    }
    
    func createPcmBuffer(pcmSamples: [PcmSample], targetFormat:AVAudioFormat, preSkip:Int64? = nil) throws -> AVAudioPCMBuffer? {
        
        let pcmFrames = UInt32(pcmSamples.count) / targetFormat.channelCount
        
        var pcmBuffer = try prepareBuffer(frames: UInt32(pcmFrames))
        try fillBuffer(pcmInterleaved: pcmSamples, buffer: &pcmBuffer)
        
        let duration = (Double(pcmBuffer.frameLength) / targetFormat.sampleRate)
        if Logger.verbose { Logger.decoding.debug("pcm buffer with \(targetFormat.channelCount) channel(s) -> \(duration*1000) ms") }
        return pcmBuffer
    }
    
    func fillBuffer(pcmInterleaved: [PcmSample], buffer: inout AVAudioPCMBuffer) throws {
        let nBuffers = buffer.audioBufferList.pointee.mNumberBuffers
        let bufferList = buffer.mutableAudioBufferList
        
        switch nBuffers {
        case 0:
            let errMsg = "AVAudioBuffer without audioBuffer"
            Logger.decoding.error(errMsg)
            throw DecoderError(.failedConverting, errMsg)
        case 1: // mono
            let audioBuffer = bufferList.pointee.mBuffers
            pcmInterleaved.withUnsafeBytes { (bufferPointer) in
                guard let addr = bufferPointer.baseAddress else { return }
                audioBuffer.mData?.copyMemory(from: addr, byteCount: Int(audioBuffer.mDataByteSize))
            }
        case 2: // stereo
            let audioBuffers = UnsafeBufferPointer<AudioBuffer>(start: &bufferList.pointee.mBuffers, count: Int(nBuffers))
            let bufferL = audioBuffers[0]
            let bufferR = audioBuffers[1]
            var left:[PcmSample] = []
            var right:[PcmSample] = []
            var iterator = pcmInterleaved.makeIterator()
            while let sampleL = iterator.next(), let sampleR = iterator.next() {
                left.append(sampleL)
                right.append(sampleR)
            }
            left.withUnsafeBytes { (bufferPointer) in
                guard let addr = bufferPointer.baseAddress else { return }
                bufferL.mData?.copyMemory(from: addr, byteCount: Int(bufferL.mDataByteSize))
            }
            right.withUnsafeBytes { (bufferPointer) in
                guard let addr = bufferPointer.baseAddress else { return }
                bufferR.mData?.copyMemory(from: addr, byteCount: Int(bufferL.mDataByteSize))
            }
            left.removeAll()
            right.removeAll()
        default:
            let errMsg = "AVAudioBuffer with multiple channels not yet supported"
            Logger.decoding.error(errMsg)
            throw DecoderError(.failedConverting, errMsg)
        }
    }
    
    func determineNAudioFrames(bytes:UnsafePointer<UInt8> , len:Int) throws -> Int? {
        let opusFrames = opus_packet_get_nb_frames(bytes, Int32(len))
        if opusFrames < 0 {
            let errMsg = "opus_packet_get_nb_frames error: \(describe(opusCode: opusFrames)) on packet with \(len) bytes"
            Logger.decoding.error(errMsg)
            throw DecoderError(.failedConverting, errMsg)
        }
        
        let audioFramesPerOpusFrame = opus_packet_get_samples_per_frame(bytes, opus_int32(pcmFormat!.sampleRate))
        let audioFrames = opusFrames * audioFramesPerOpusFrame
        if Logger.verbose { Logger.decoding.debug("\(audioFrames) audio frames in packet (\(opusFrames) packet frames per \(audioFramesPerOpusFrame) audio frame)") }
        
        if audioFrames > 120*48 {
            let errMsg = "audio packet error: no of audio frames \(audioFrames) > 120*48"
            Logger.decoding.error(errMsg)
            throw DecoderError(.failedConverting, errMsg)
        }
        return Int(audioFrames)
    }
    
    static func describeOpusCode(_ errorCode:opus_int32) -> String {
        return describe(opusCode: errorCode)
    }
}

fileprivate func describe(opusCode errorCode:opus_int32) -> String {
    return String(cString: opus_strerror(errorCode))
}
