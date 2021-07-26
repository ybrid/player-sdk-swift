//
// AudioDecoder.swift
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

protocol DecoderListener: MetadataListener {
    func onFormatChanged(_ srcFormat : AVAudioFormat)
    func pcmReady(pcmBuffer: AVAudioPCMBuffer)
}
typealias DecoderNotification = (ErrorSeverity, DecoderError)->()
class AudioDecoder : AudioDataListener {
    
    let listener: DecoderListener
    let notify: DecoderNotification?
    var pcmFormat: AVAudioFormat?
    
    var stopping = false
    
    
    static func factory(_ mimeType: String?, _ filename: String?, listener: DecoderListener, notify: @escaping DecoderNotification) throws -> AudioDecoder {

        guard let mimeType = mimeType else {
            throw AudioDataError(.missingMimeType, "missing mimeType")
        }
    
        if isOpusAudioFileType( mimeType )  {
            Logger.loading.debug("mimeType \(mimeType) resolved to opus decoder")
            return try AudioDecoder.createOpusDecoder(listener: listener)
        }
        if let name = filename {
            if isOpusAudioFileType(filename: name) {
                Logger.loading.debug("mimeType \(mimeType) with filename \(name) resolved to opus decoder")
                return try AudioDecoder.createOpusDecoder(listener: listener)
            }
            if "txt" == (name as NSString).pathExtension { // todo throw excp in SystemDecoder
                throw AudioDataError(.cannotProcessMimeType, "cannot process \(mimeType) with filename \(name)")
            }
        }
        
        Logger.loading.debug("mimeType \(mimeType) resolved to system audio decoder")
        return try AudioDecoder.createSystemDecoder(listener: listener, notify: notify)
    }

    private static func isOpusAudioFileType(_ mimeType:String) -> Bool {
        switch mimeType {
        case "application/ogg", "audio/ogg":
            return true
        default:
            return false
        }
    }

    private static func isOpusAudioFileType(filename:String) -> Bool {
        let ext = (filename as NSString).pathExtension
        switch ext {
        case "opus":
            return true
        default:
            return false
        }
    }
    
    static func createOpusDecoder(listener: DecoderListener) throws -> AudioDecoder {
        let ogg = try OggContainer()
        return try OpusDecoder(container: ogg, decodingListener: listener)
    }

    static func createSystemDecoder(listener: DecoderListener, notify: @escaping DecoderNotification) throws -> AudioDecoder {
        return try SystemDecoder(decodingListener: listener, notify: notify)
    }

    
    internal init(decodingListener: DecoderListener, notify: DecoderNotification? = nil ) throws {
        self.listener = decodingListener
        self.notify = notify
    }

    // MARK: audio data listener

    func onFormatChanged(_ srcFormat: AVAudioFormat) {

        do {
            let pcmFormat = try self.create(from: srcFormat)
            listener.onFormatChanged(pcmFormat)
        } catch {
            if let decoderError = error as? DecoderError {
                notify?(ErrorSeverity.fatal, decoderError)
            } else {
                notify?(ErrorSeverity.fatal, DecoderError(ErrorKind.unknown, error))
            }
        }
    }
    
    func pcmReady(pcmBuffer: AVAudioPCMBuffer) {
        listener.pcmReady(pcmBuffer: pcmBuffer)
    }
    
    // MARK: must be overridden
    
    internal func create(from sourceFormat: AVAudioFormat) throws -> AVAudioFormat {
        fatalError(#function + " must be overridden")
    }
    
    internal func decode(data: Data) throws {
        fatalError(#function + " must be overridden")
    }
    
    internal func dispose() {
        fatalError(#function + " must be overridden")
    }

    func prepareBuffer(frames: UInt32) throws  -> AVAudioPCMBuffer {
        
        guard let targetFormat = pcmFormat else {
            Logger.decoding.error("target format missing")
            throw DecoderError(.missingTargetFormat)
        }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frames) else {
            throw DecoderError(.failedToAllocatePCMBuffer)
        }
        buffer.frameLength = frames
        return buffer
    }
}

