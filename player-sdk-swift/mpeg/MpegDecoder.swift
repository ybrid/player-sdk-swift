//
// MpegDecoder.swift
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

class MpegDecoder : AudioDecoder {
    
    fileprivate var converter: AudioConverterRef? = nil
    var source: MpegData?
    
    override init(audioContentType: AudioFileTypeID, decodingListener: DecoderListener) throws {
        try super.init(audioContentType: audioContentType, decodingListener: decodingListener)
        source = try MpegData(audioContentType: audioContentType, listener: self)
    }
    
    deinit {
        Logger.decoding.debug()
    }
    
    // MARK: base audio decoder
    
    override func dispose() {
        Logger.decoding.debug("pre deinit")
        if let converter = converter {
            guard AudioConverterDispose(converter) == noErr else {
                Logger.decoding.error("failed to dispose audio converter")
                return
            }}
        cleanupConverterGarbage()
    }
    
    override func create(from sourceFormat:AVAudioFormat) throws -> AVAudioFormat {
        let targetFormat = calcPcmFormat(sourceFormat)
        Logger.decoding.info("source format \(AudioPipeline.describeFormat(sourceFormat))")
        Logger.decoding.info("target format \(AudioPipeline.describeFormat(targetFormat))")
        if let converter = converter {
            if AudioConverterDispose(converter) != noErr {
                Logger.decoding.error("failed to dispose audio converter")
            }}
        
        let result = AudioConverterNew(sourceFormat.streamDescription, targetFormat.streamDescription, &converter)
        guard result == noErr else {
            throw DecoderError(.cannotCreateConverter, result)
        }
        self.pcmFormat = targetFormat
        return targetFormat
    }
    
    private func calcPcmFormat(_ sourceFormat: AVAudioFormat) -> AVAudioFormat {
        return AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sourceFormat.sampleRate, channels: sourceFormat.channelCount, interleaved: false)!
    }
    
    override func decode(data: Data) throws {
        guard !super.stopping else {
            Logger.decoding.debug("stopping, ignoring data")
            return
        }
        
        do {
            try source?.parse(data: data)
        } catch {
            let err = DecoderError(.failedPackaging)
            err.cause = error
            throw err
        }
        
        guard let newPackages = source?.packages.count, newPackages > 0 else {
            return // just nothing to convert
        }

        let buffer = try convert(newPackages: newPackages)

        if let count = source?.packages.count, count > 0 {
            Logger.decoding.notice("DIFF audio packages \(count) not converted yet")
        }

        self.pcmReady(pcmBuffer: buffer)
    }
    
    private func convert(newPackages:Int) throws -> AVAudioPCMBuffer {
        guard let sourceFormat = source?.format else {
            Logger.decoding.error("source format missing")
            throw DecoderError(.missingSourceFormat)
        }
        let sFpp = sourceFormat.streamDescription.pointee.mFramesPerPacket
        guard let targetFormat = pcmFormat else {
            Logger.decoding.error("target format missing")
            throw DecoderError(.missingTargetFormat)
        }
        let tFpp = targetFormat.streamDescription.pointee.mFramesPerPacket
        let pcmFrames = UInt32(newPackages) * sFpp / tFpp
        
        let buffer = try prepareBuffer(frames: pcmFrames)
        let context = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        let status = AudioConverterFillComplexBuffer(converter!, convertPacketCallback, context, &buffer.frameLength, buffer.mutableAudioBufferList, nil)
        if Logger.verbose { Logger.decoding.debug("has read \(buffer.frameLength) frames into buffer of capacity \(pcmFrames) -> '\(AudioDecoder.describeConverting(status))'") }
        
        cleanupConverterGarbage()
        
        guard status == noErr || status == ConvertingEndOfData else {
            Logger.decoding.error("AudioConverterFillComplexBuffer returned os status \(AudioDecoder.describeConverting(status))")
            switch status {
            case ConvertingMissingSourceFormat:
                throw DecoderError(.missingSourceFormat)
            case ConvertingMissingDataSource:
                throw DecoderError(.missingDataSource)
            default:
                throw DecoderError(.failedConverting, status)
            }
        }
        
        return buffer
    }

    /// need to keep in mind memory of packet data and descriptions to deallocate after converting
    fileprivate var packetDescs:[UnsafeMutablePointer<AudioStreamPacketDescription>?] = []
    fileprivate var packetDatas:[UnsafeMutableRawPointer?] = []
    fileprivate func cleanupConverterGarbage() {
        packetDescs.forEach { (desc) in desc?.deinitialize(count: 1); desc?.deallocate() }
        if Logger.verbose { Logger.decoding.debug("deallocated \(packetDescs.count) packet descriptions") }
        packetDescs.removeAll()
        packetDatas.forEach { (data) in data?.deallocate() }
        if Logger.verbose { Logger.decoding.debug("deallocated \(packetDatas.count) packets of data") }
        packetDatas.removeAll()
    }

    /// called for each packet by convertPacketCallback
    fileprivate func convertPacket(_ packetCount: inout UInt32,
                                   _ outData: inout AudioBufferList,
                                   _ outDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?) -> OSStatus {

        guard var packet = source?.packages.take() else {
            return ConvertingEndOfData
        }

        /// converter uses this data
        let bytesCount = packet.data.count
        outData.mNumberBuffers = 1
        outData.mBuffers.mData = UnsafeMutableRawPointer.allocate(byteCount: bytesCount, alignment: 0)
        _ = packet.data.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
            memcpy((outData.mBuffers.mData?.assumingMemoryBound(to: UInt8.self))!, bytes.baseAddress, bytesCount)
        }
        outData.mBuffers.mDataByteSize = UInt32(bytesCount)
        packetDatas.append(outData.mBuffers.mData) /// needs to be cleaned up
        
        /// converter needs description if not pcm (mFormatID != kAudioFormatLinearPCM)
        if var desc = packet.description {
            desc.mStartOffset = 0
            if outDescription?.pointee == nil {
                outDescription?.pointee = UnsafeMutablePointer<AudioStreamPacketDescription>.allocate(capacity: 1)
                outDescription?.pointee?.initialize(to: desc)
            }
            outDescription?.pointee?[0] = desc
            packetDescs.append(outDescription?.pointee) /// needs to be cleaned up
        }
        
        packetCount = 1
        return noErr
    }
}

/// Synchronous Callback
fileprivate func convertPacketCallback(_ converter: AudioConverterRef,
                           _ packetCount: UnsafeMutablePointer<UInt32>,
                           _ outBufferList: UnsafeMutablePointer<AudioBufferList>,
                           _ outPacketDescriptions: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?,
                           _ context: UnsafeMutableRawPointer?) -> OSStatus {
    let converter = Unmanaged<MpegDecoder>.fromOpaque(context!).takeUnretainedValue()
    return converter.convertPacket(&packetCount.pointee, &outBufferList.pointee, outPacketDescriptions)
}
