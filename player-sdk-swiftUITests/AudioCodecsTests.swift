//
// AudioCodecsTests.swift
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

import XCTest
import YbridPlayerSDK

class AudioCodecsTests: XCTestCase {
    

    /*
     Audio codec AAC are supported up to profile HE-AAC_v2.
     
     Besides the first sine you should hear 4 different high frequencies.
     The first ones on the left. The second ones on the right channel.
     */
    func test20_playingHEAACv2() {
        _ = TestControl(aacHEv2Endpoint)
            .playing(6)
            .checkErrors(expected: 0)
    }

    /*
     
     */
    func test21_playingSpeechMale_HEAACv1_XHEAAC() {
        _ = TestControl(heaac24kbps_SpeechMale)
            .playing(6)
            .checkErrors(expected: 0)
            
            .select(xheaac24kbps_SpeechMale)
            .playing(6)
            .checkErrors(expected: 0)
    }
    
    func test22_playingMusic_24kbps_HEAACv1_XHEAAC() {
        _ = TestControl(heaac24kbps_music)
            .playing(6)
            .checkErrors(expected: 0)

            .select(xheaac24kbps_music)
            .playing(6)
            .checkErrors(expected: 0)
    }
    
    func test22_playingMusic_48kbps_HEAACv1_XHEAAC() {
        _ = TestControl(heaac48kbps_music)
            .playing(12)
            .checkErrors(expected: 0)

            .select(xheaac48kbps_music)
            .playing(12)
            .checkErrors(expected: 0)
    }
    
    func test23_playingMusic_128kbps_HEAACv1_XHEAAC() {
        _ = TestControl(heaac128kbps_music)
            .playing(18)
            .checkErrors(expected: 0)
        
            .select(xheaac128kbps_music)
            .playing(18)
            .checkErrors(expected: 0)
    }
}

// @see https://www2.iis.fraunhofer.de/AAC/stereo.html
let gitTestfilesAacUrl = "https://github.com/ybrid/test-files/blob/main/aac/fraunhofer/"


// @see https://www2.iis.fraunhofer.de/AAC/xhe-aac-compare-tab.html
let heaac24kbps_SpeechMale = MediaEndpoint( mediaUri:  gitTestfilesAacUrl + "sqam50_LN_HEAACv1_024s_AACLC_320s.mp4?raw=true" )
let xheaac24kbps_SpeechMale = MediaEndpoint( mediaUri: gitTestfilesAacUrl + "sqam50_LN_xHE_024s_AACLC_320s.mp4?raw=true")

let heaac24kbps_music = MediaEndpoint(mediaUri: gitTestfilesAacUrl + "Walking01_LN_AACLC_024s_AACLC_320s.mp4?raw=true")
let xheaac24kbps_music = MediaEndpoint(mediaUri: gitTestfilesAacUrl + "Walking01_LN_xHE_024s_AACLC_320s.mp4?raw=true")
let heaac48kbps_music = MediaEndpoint(mediaUri: gitTestfilesAacUrl + "Farewell01_LN_AACLC_048s_AACLC_320s.mp4?raw=true")
let xheaac48kbps_music = MediaEndpoint(mediaUri: gitTestfilesAacUrl + "Farewell01_LN_xHE_048s_AACLC_320s.mp4?raw=true")
let heaac128kbps_music = MediaEndpoint(mediaUri: gitTestfilesAacUrl + "Walking01_LN_AACLC_128s_AACLC_320s.mp4?raw=true")
let xheaac128kbps_music = MediaEndpoint(mediaUri: gitTestfilesAacUrl + "Walking01_LN_xHE_128s_AACLC_320s.mp4?raw=true")
