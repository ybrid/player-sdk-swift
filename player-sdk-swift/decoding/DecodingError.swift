//
// DecodingError.swift
// player-sdk-swift
//
// Copyright (c) 2021 nacamar GmbH - Ybrid®, a Hybrid Dynamic Live Audio Technology
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

import Foundation
import AVFoundation

public class AudioDataError : AudioPlayerError {

    init(_ kind: ErrorKind) {
        super.init(kind, nil)
    }
    
    // used with system converter from os
    init(_ kind: ErrorKind, _ code: OSStatus) {
        super.init(kind, describe(osstatus: code))
        super.osstatus = code
    }

    // used with opus
    init(_ kind: ErrorKind, _ message: String, _ cause: Error? = nil) {
        super.init(kind, message, cause)
    }

}

public class DecoderError : AudioPlayerError {

    init(_ kind:ErrorKind, _ code: OSStatus? = nil) {
        guard let code = code else {
            super.init(kind, nil)
            return
        }
        super.init(kind, SystemDecoder.describeConverting(code))
        super.osstatus = code
    }
    init(_ kind:ErrorKind, _ message: String) {
        super.init(kind, message)
    }
    init(_ kind:ErrorKind, _ cause: Error) {
        super.init(kind, nil, cause)
    }
}


fileprivate func describe(osstatus: OSStatus) -> String {
    switch osstatus {
    case kAudioFileStreamError_UnsupportedFileType:
        return "The file type is not supported."
    case kAudioFileStreamError_UnsupportedDataFormat:
        return "The data format is not supported by this file type."
    case kAudioFileStreamError_UnsupportedProperty:
        return "The property is not supported."
    case kAudioFileStreamError_BadPropertySize:
        return "The size of the property data was not correct."
    case kAudioFileStreamError_NotOptimized:
        return "It is not possible to produce output packets because the file's packet table or other defining info is either not present or is after the audio data."
    case kAudioFileStreamError_InvalidPacketOffset:
        return "A packet offset was less than zero, or past the end of the file, or a corrupt packet size was read when building the packet table."
    case kAudioFileStreamError_InvalidFile:
        return "The file is malformed, or otherwise not a valid instance of an audio file of its type, or is not recognized as an audio file."
    case kAudioFileStreamError_ValueUnknown:
        return "The property value is not present in this file before the audio data."
    case  kAudioFileStreamError_DataUnavailable:
        return "The amount of data provided to the parser was insufficient to produce any result."
    case  kAudioFileStreamError_IllegalOperation:
        return "An illegal operation was attempted."
    case kAudioFileStreamError_UnspecifiedError:
        return "An unspecified error has occurred."
    default:
        return "unknown os status code \(osstatus)"
    }
}

