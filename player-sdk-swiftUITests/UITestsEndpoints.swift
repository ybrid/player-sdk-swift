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
import YbridPlayerSDK

let ybridDemoEndpoint = MediaEndpoint(mediaUri: "https://democast.ybrid.io/adaptive-demo")
let ybridAdDemoEndpoint = MediaEndpoint(mediaUri: "https://democast.ybrid.io/ad-injection-demo")
let ybridStageSwr3Endpoint = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/swr3/mp3/mid").forceProtocol(.ybridV2)
let ybridSwr3Endpoint = MediaEndpoint(mediaUri: "http://swr-swr3.cast.ybrid.io/swr/swr3/ybrid").forceProtocol(.ybridV2)
let ybridStageDemoEndpoint = MediaEndpoint(mediaUri: "https://stagecast.ybrid.io/adaptive-demo")

let icecastSwr3Endpoint = MediaEndpoint(mediaUri: "http://swr-swr3-live.cast.addradio.de/swr/swr3/live/mp3/128/stream.mp3")
let icecastHr2Endpoint = MediaEndpoint(mediaUri: "https://hr-hr2-live.cast.addradio.de/hr/hr2/live/mp3/128/stream.mp3").forceProtocol(MediaProtocol.icy)
let opusDlfEndpoint = MediaEndpoint(mediaUri: "https://dradio-dlf-live.cast.addradio.de/dradio/dlf/live/opus/high/stream.opus")
let opusCCEndpoint = MediaEndpoint(mediaUri: "http://theradio.cc:8000/trcc-stream.opus")
let onDemandOpusEndpoint = MediaEndpoint(mediaUri: "https://opus-codec.org/static/examples/ehren-paper_lights-96.opus")
let onDemandMp3Endpoint = MediaEndpoint(mediaUri: "https://github.com/ybrid/test-files/blob/main/mpeg-audio/music/music.mp3?raw=true")


let aac441Endpoint = MediaEndpoint(mediaUri:    "https://www2.iis.fraunhofer.de/AAC/xheDemo/Walking01_LN_xHE_024s_AACLC_320s.mp4") // AAC 44,1 kHz
let aac480Endpoint = MediaEndpoint(mediaUri:     "https://www2.iis.fraunhofer.de/AAC/xheDemo/Rain01_LN_xHE_016s_AACLC_320s.mp4") // AAC 48 kHz


//
// @see https://www2.iis.fraunhofer.de/AAC/stereo.html
// tests for proper reproduction of the SBR portion of the HE-AAC bitstream and proper channel arrangement.

//  AOT 5, explicit signalling, backwards compatible -> HE-AAC, 'aach'
let aacHEEndpoint =  MediaEndpoint(mediaUri:"https://www2.iis.fraunhofer.de/AAC/SBRtestStereoAot5Sig1.mp4")
// AOT 29, explicit signalling, backwards compatible ->  HE-AAC_v2, 'aacp'
let aacHEv2aachEndpoint = MediaEndpoint(mediaUri:"https://www2.iis.fraunhofer.de/AAC/SBRtestStereoAot29Sig1.mp4")
// AOT 29, explicit signalling, not backwards compatible (MPEG hierarchical) ->  HE-AAC_v2, 'aacp'
let aacHEv2aacpEndpoint = MediaEndpoint(mediaUri:"https://www2.iis.fraunhofer.de/AAC/SBRtestStereoAot29Sig2.mp4")
// AOT 29, implicit signalling -> HE-AAC_v2 not detected, using 'aac ' (playing without SBR), 1ch
let aacNoSBREndpoint = MediaEndpoint(mediaUri:"https://www2.iis.fraunhofer.de/AAC/SBRtestStereoAot29Sig0.mp4")
// mixed signaling -> HE-AAC_v2 'aach', 1 ch
let aacMixed1ChEndpoint = MediaEndpoint(mediaUri:"https://www2.iis.fraunhofer.de/AAC/SBRtestStereoAot5SigusePS.mp4")
