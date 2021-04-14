//
// AudioPlayerError.swift
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

public enum ErrorSeverity {
    case fatal
    case recoverable
    case notice
}

public typealias ErrorCode = Int32
enum ErrorKind : ErrorCode {
    case noError = 0
    case unknown = 100
    case memoryLimitExceeded = 101
    
    // audio data loading
    case networkFatal = 201
    case networkStall = 202
    
    // audio data, reading http header
    case missingMimeType = 301
    case cannotProcessMimeType = 302

    // audio data, reading 
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
    case badData = 529
    
    // api and session
    case invalidUri = 601
    case serverError = 603
    case invalidResponse = 604
    case noSession = 605
    case invalidSession = 606
    
}

public class AudioPlayerError : LocalizedError {
    
    let kind:ErrorKind
    var cause:Error?
    
    public var code:ErrorCode { return kind.rawValue }
    public var message:String?
    public var osstatus:OSStatus?
    
    init(_ errorKind:ErrorKind, _ message:String?, _ cause:Error? = nil) {
        self.kind = errorKind
        self.message = message
        self.cause = cause
    }
    
    public var errorDescription: String? {
        var description = failureReason!
        if let code = osstatus {
            description += String(format: ", OSStatus=%d", code)
        }
        if let msg = message {
            description += ", " + msg
        }
        if let cause = cause {
            description += ", cause: \(cause.localizedDescription)"
        }
        return description
    }
    public var failureReason: String? {
        return String(format:"%d %@.%@", code, "\(type(of: self))", "\(kind)")
    }
}

