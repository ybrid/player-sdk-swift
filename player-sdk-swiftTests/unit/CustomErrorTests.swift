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
        let err = AudioDataError(.parsingFailed, noErr)
        XCTAssertEqual("AudioDataError.parsingFailed Code=0 \"unknown result code 0\"",err.localizedDescription)
        
    }
    
    func testParsingFailed() throws {
       let err = AudioDataError(.parsingFailed, kAudioFileStreamError_UnsupportedFileType)
       XCTAssertEqual("AudioDataError.parsingFailed Code=1954115647 \"The file type is not supported.\"",err.localizedDescription)
    }
    
    
    func testDecoderError() throws {
        let err = DecoderError(.missingDataSource)
       XCTAssertEqual("DecoderError.missingDataSource",err.localizedDescription)
   }

    func testFailedConverting() throws {
        let err = DecoderError(.cannotCreateConverter, noErr)
       XCTAssertEqual("DecoderError.cannotCreateConverter Code=0 \"ok\"",err.localizedDescription)
   }
    
    func testPipelineError() throws {
        let err = LoadingError(.cannotProcess, "mp4")
        XCTAssertEqual("LoadingError.cannotProcess mp4",err.localizedDescription)
    }
}
