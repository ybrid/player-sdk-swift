//
// CustomErrorTests.swift
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

import XCTest
import AVFoundation
@testable import YbridPlayerSDK

class CustomErrorTests: XCTestCase {
    
    func testAudioDataError() throws {
        let err = AudioDataError(.missingMimeType)
        XCTAssertEqual(301, err.code)
        XCTAssertEqual("301 AudioDataError.missingMimeType", err.failureReason)
        XCTAssertNil(err.message)
        XCTAssertNil(err.cause)
        XCTAssertEqual("301 AudioDataError.missingMimeType", err.localizedDescription)
    }
    func testAudioDataError_Message() throws {
        let err = AudioDataError(.parsingFailed, "mein Fehler")
        XCTAssertEqual(412, err.code)
        XCTAssertEqual("412 AudioDataError.parsingFailed", err.failureReason)
        XCTAssertEqual("mein Fehler", err.message)
        XCTAssertNil(err.cause)
        XCTAssertEqual("412 AudioDataError.parsingFailed, mein Fehler", err.localizedDescription)
    }
    func testAudioDataError_oscode() throws {
        let err = AudioDataError(.parsingFailed, kAudioFileStreamError_UnsupportedFileType)
        XCTAssertEqual("412 AudioDataError.parsingFailed", err.failureReason)
        XCTAssertEqual("The file type is not supported.", err.message)
        XCTAssertEqual(kAudioFileStreamError_UnsupportedFileType, err.osstatus)
        XCTAssertEqual("412 AudioDataError.parsingFailed, OSStatus=1954115647, The file type is not supported.", err.localizedDescription)
    }
    
    func testDecoderError_noMessage() throws {
        let err = DecoderError(.missingDataSource)
        XCTAssertEqual("524 DecoderError.missingDataSource", err.failureReason)
        XCTAssertNil(err.message)
        XCTAssertNil(err.osstatus)
        XCTAssertEqual("524 DecoderError.missingDataSource", err.localizedDescription)
    }
    
    func testDecoderError() throws {
        let err = DecoderError(.cannotCreateConverter, noErr)
        XCTAssertEqual("523 DecoderError.cannotCreateConverter", err.failureReason)
        XCTAssertEqual(0, err.osstatus)
        XCTAssertEqual("ok", err.message)
        XCTAssertEqual("523 DecoderError.cannotCreateConverter, OSStatus=0, ok", err.localizedDescription)
    }
    
    func testDecoderError_WithCause() throws {
        let err = DecoderError(.failedConverting, AudioDataError(ErrorKind.unknown, "aborted decoding"))
        XCTAssertEqual("527 DecoderError.failedConverting", err.failureReason)
        XCTAssertNil(err.osstatus)
        XCTAssertNil(err.message)
        XCTAssertEqual("527 DecoderError.failedConverting, cause: 100 AudioDataError.unknown, aborted decoding", err.localizedDescription)
    }

    
    func testLoadingError_Message() throws {
        let err = LoadingError(ErrorKind.networkFatal, "any error")
        XCTAssertEqual("201 LoadingError.networkFatal", err.failureReason)
        XCTAssertNil(err.osstatus)
        XCTAssertEqual("any error", err.message)
        XCTAssertEqual("201 LoadingError.networkFatal, any error", err.localizedDescription)
    }
    
    
    func testLoadingError_MessageCause() throws {
        let err = LoadingError(ErrorKind.networkFatal, "don't understand",LoadingError(ErrorKind.unknown, "suddenly gone"))
        XCTAssertEqual("201 LoadingError.networkFatal", err.failureReason)
        XCTAssertNil(err.osstatus)
        XCTAssertEqual("don't understand", err.message)
        XCTAssertEqual("201 LoadingError.networkFatal, don't understand, cause: 100 LoadingError.unknown, suddenly gone", err.localizedDescription)
    }
   
    
    func testLoadingError_SessionCause() throws {
        let err = LoadingError(ErrorKind.networkFatal, SessionTaskState(-1003, "unknown host", ErrorSeverity.fatal))
        XCTAssertEqual("201 LoadingError.networkFatal", err.failureReason)
        XCTAssertEqual(-1003, err.osstatus)
        XCTAssertEqual("unknown host", err.message)
        XCTAssertEqual("201 LoadingError.networkFatal, OSStatus=-1003, unknown host, cause: SessionTaskState OSStatus=-1003, unknown host", err.localizedDescription)
    }
}
