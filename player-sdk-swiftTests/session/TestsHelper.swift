//
// UITestsEndpoints.swift
// app-example-iosUITests
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
import XCTest
@testable import YbridPlayerSDK

// demo
let ybridDemoEndpoint = MediaEndpoint(mediaUri: "https://democast.ybrid.io/adaptive-demo")
let ybridAdDemoEndpoint = MediaEndpoint(mediaUri: "https://democast.ybrid.io/ad-injection-demo")

// stage
let ybridStageDemoEndpoint = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/adaptive-demo")
let ybridStageSwr3Endpoint = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/swr3/mp3/mid")

// prod
let ybridSwr3Endpoint = MediaEndpoint(mediaUri: "https://swr-swr3.cast.ybrid.io/swr/swr3/ybrid").forceProtocol(.ybridV2)

let icecastSwr3Endpoint = MediaEndpoint(mediaUri: "http://swr-swr3-live.cast.addradio.de/swr/swr3/live/mp3/128/stream.mp3")
let icecastHr2Endpoint = MediaEndpoint(mediaUri: "https://hr-hr2-live.cast.addradio.de/hr/hr2/live/mp3/128/stream.mp3")
let opusDlfEndpoint = MediaEndpoint(mediaUri: "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")
let opusCCEndpoint = MediaEndpoint(mediaUri: "http://theradio.cc:8000/trcc-stream.opus")
let onDemandOpusEndpoint = MediaEndpoint(mediaUri: "https://opus-codec.org/static/examples/ehren-paper_lights-96.opus")
let onDemandMp3Endpoint = MediaEndpoint(mediaUri: "https://github.com/ybrid/test-files/blob/main/mpeg-audio/music/music.mp3?raw=true")

class ErrorListener : AudioPlayerListener {
    func cleanUp() {
        errors.removeAll()
    }
    
    func stateChanged(_ state: PlaybackState) {}
    func metadataChanged(_ metadata: Metadata) {}
    func playingSince(_ seconds: TimeInterval?) {}
    func durationReadyToPlay(_ seconds: TimeInterval?) {}
    func durationConnected(_ seconds: TimeInterval?) {}
    func bufferSize(averagedSeconds: TimeInterval?, currentSeconds: TimeInterval?) {}
    
    var errors:[AudioPlayerError] = []
    func error(_ severity: ErrorSeverity, _ exception: AudioPlayerError) {
        errors.append(exception)
    }
}


class Poller {
    
    func wait(_ control:PlaybackControl, untilState:PlaybackState, maxS:Int) {
        return wait(control, untilState: untilState, intervalMs: 1_000, maxS: maxS)
    }
    
    func wait(_ control:PlaybackControl, untilState:PlaybackState, intervalMs:UInt32, maxS:Int) {
        let maxMs = UInt32(maxS) * 1000
        let took = wait(maxMs: maxMs, intervalMs: intervalMs) {
            return control.state == untilState
        }
        XCTAssertLessThanOrEqual(took, maxMs, "not \(untilState) within \(maxS) s")
    }
    
    private func wait(maxMs max:UInt32, intervalMs: UInt32, until:() -> (Bool)) -> UInt32 {
        var millis:UInt32 = 0
        let stepUs = intervalMs * 1000
        while !until() && millis <= max {
            usleep(stepUs)
            millis += intervalMs
        }
        XCTAssertTrue(until(), "condition not satisfied within \(millis) ms")
        return millis
    }
}
