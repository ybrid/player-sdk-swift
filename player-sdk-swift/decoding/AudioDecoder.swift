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
    
    static let factory = AudioDecoderFactory()
    
    let listener: DecoderListener
    let notify: DecoderNotification?
    var pcmFormat: AVAudioFormat?
    
    var stopping = false
    
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

