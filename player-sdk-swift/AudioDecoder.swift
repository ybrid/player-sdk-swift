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

protocol DecoderListener  {
    func onFormatChanged(_ srcFormat : AVAudioFormat)
    func pcmReady(pcmBuffer: AVAudioPCMBuffer)
}

class AudioDecoder : AudioDataListener {
    
    let listener: DecoderListener
    var pcmFormat: AVAudioFormat?
    
    var stopping = false
    
    internal init(audioContentType: AudioFileTypeID, decodingListener: DecoderListener) throws {
        self.listener = decodingListener
    }
    
    func pcmReady(pcmBuffer: AVAudioPCMBuffer) {
        listener.pcmReady(pcmBuffer: pcmBuffer)
    }
    
    // MARK: audio data listener
    
    func onFormatChanged(_ srcFormat: AVAudioFormat) {
        listener.onFormatChanged(srcFormat)
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
    
    static func describeConverting(_ status: OSStatus) -> String {
        switch status {
        case noErr:
            return "ok"
        case ConvertingEndOfData:
            return "end of data"
        case ConvertingMissingDataSource:
            return "missing data source"
        case ConvertingMissingSourceFormat:
            return "missing source format"
        case kAudioConverterErr_RequiresPacketDescriptionsError:
            return "kAudioConverterErr_RequiresPacketDescriptionsError"
        /// not seen yet
        case kAudioConverterErr_OperationNotSupported:
            return "kAudioConverterErr_OperationNotSupported"
        case kAudioConverterErr_FormatNotSupported:
            return "kAudioConverterErr_FormatNotSupported"
        case kAudioConverterErr_PropertyNotSupported:
            return "kAudioConverterErr_PropertyNotSupported"
        case kAudioConverterErr_InvalidInputSize:
            return "kAudioConverterErr_InvalidInputSize"
        case kAudioConverterErr_InvalidOutputSize:
            return "kAudioConverterErr_InvalidOutputSize"
        case kAudioConverterErr_UnspecifiedError:
            return "kAudioConverterErr_UnspecifiedError"
        case kAudioConverterErr_BadPropertySizeError:
            return "kAudioConverterErr_BadPropertySizeError"
        case kAudioConverterErr_RequiresPacketDescriptionsError:
            return "kAudioConverterErr_RequiresPacketDescriptionsError"
        case kAudioConverterErr_InputSampleRateOutOfRange:
            return "kAudioConverterErr_InputSampleRateOutOfRange"
        case kAudioConverterErr_OutputSampleRateOutOfRange:
            return "kAudioConverterErr_OutputSampleRateOutOfRange"
#if os(iOS)
        case kAudioConverterErr_HardwareInUse:
            return "Hardware is in use"
        case kAudioConverterErr_NoHardwarePermission:
            return "No hardware permission"
#endif
        default:
            return "\(status) (unknown state)"
        }
    }
}

class DecoderError : LocalizedError {
    enum ErrorKind {
        case missingSourceFormat
        case missingTargetFormat
        case cannotCreateConverter
        case missingDataSource
        case failedPackaging
        case failedToAllocatePCMBuffer
        case failedConverting
        case invalidData
    }
    let kind:ErrorKind
    var oscode: OSStatus?
    var message: String?
    var cause: Error?
    init(_ kind:ErrorKind, _ code: OSStatus? = nil) {
        self.kind = kind; self.oscode = code
    }
    init(_ kind:ErrorKind, _ message: String) {
        self.kind = kind; self.message = message
    }
    init(_ kind:ErrorKind, _ cause: Error) {
        self.kind = kind; self.cause = cause
    }
    var errorDescription: String? {
        var desc = String(format:"%@.%@", String(describing: Self.self), String(describing: kind))
        if let oscode = oscode {
            desc = desc + String(format: " Code=%d \"%@\"", oscode, AudioDecoder.describeConverting(oscode))
        }
        if let message = message {
            desc = desc + ", '" + message + "'"
        }
        if let cause = cause {
            desc = desc + ", cause: " + cause.localizedDescription
        }
        return desc
    }
}

/// possible os' return codes of convertPacketsCallback
let ConvertingEndOfData: OSStatus = 800000001
let ConvertingMissingDataSource: OSStatus = 800000002
let ConvertingMissingSourceFormat: OSStatus = 800000003
