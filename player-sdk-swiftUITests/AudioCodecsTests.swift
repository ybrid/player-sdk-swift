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

//    OK
//    kAudioFileStreamProperty_FormatList altering source format to audio aac  2 ch 44100 Hz no pcm interleaved
    func testEspressif_aac() {
        play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.aac"))
    }
    
//    ok
//    kAudioFileStreamProperty_DataFormat using source format audio ac-3 2 ch 44100 Hz no pcm interleaved
    func testEspressif_ac3() {
        play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.ac3"))
    }
    
//    ok
//    kAudioFileStreamProperty_DataFormat using source format audio .mp3 2 ch 44100 Hz no pcm interleaved
    func testEspressif_mp3() {
        play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.mp3"))
    }
    
    
//    ok
//    kAudioFileStreamProperty_DataFormat using source format audio lpcm 2 ch 44100 Hz pcmInt16 interleaved
    func testEspressif_aiff() {
        play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.aiff"))
    }
    
//    ok
//    kAudioFileStreamProperty_DataFormat using source format audio flac 2 ch 44100 Hz no pcm interleaved
    func testEspressif_flac() {
        play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.flac"))
    }
    
//    fails
//    2021-09-21 17:02:29.378631+0200 app-example-ios[1590:65777] [loading] AudioDecoderFactory.createDecoder-44 mimeType audio/x-m4a resolved to system audio decoder with hint kAudioFileMPEG4Type
//    2021-09-21 17:02:29.379508+0200 app-example-ios[1590:65783] [decoding] SystemAudioData.parse-89 kAudioFileStreamProperty_FileFormat m4af unused
    // 2021-09-21 16:46:07.586683+0200 app-example-ios[1293:35035] [] AudioPlayer.notify-252 fatal 525 DecoderError.failedPackaging, cause: 412 AudioDataError.parsingFailed, OSStatus=1869640813, It is not possible to produce output packets because the file's packet table or other defining info is either not present or is after the audio data.
    func testEspressif_m4a__fails() {
        play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.m4a"))
    }
    
    // fails
//2021-09-21 17:03:49.649441+0200 app-example-ios[1615:67676] [loading] AudioDecoderFactory.createDecoder-44 mimeType video/mp4 resolved to system audio decoder with hint kAudioFileMPEG4Type
//    2021-09-21 17:03:49.650200+0200 app-example-ios[1615:67685] [decoding] SystemAudioData.parse-89 kAudioFileStreamProperty_FileFormat mp4f unused
    // 2021-09-21 16:47:00.497239+0200 app-example-ios[1312:36539] [] AudioPlayer.notify-252 fatal 525 DecoderError.failedPackaging, cause: 412 AudioDataError.parsingFailed, OSStatus=1869640813, It is not possible to produce output packets because the file's packet table or other defining info is either not present or is after the audio data.
    func testEspressif_mp4__fails() {
        play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.mp4"))
    }
    
    
    
    // Does not decode, nothing to hear
    // OggContainer.parse finds "no stream for ...."
    func testEspressif_ogg__fails() {
        play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.ogg"))
    }

    // ok
//    2021-09-21 16:51:19.493795+0200 app-example-ios[1414:47315] [decoding] OpusData.mapOpusPacket-207 bos opus packet 0
//    2021-09-21 16:51:19.493964+0200 app-example-ios[1414:47315] [decoding] OpusData.onOpusHead-221 OpusHead ver 1, ch 2, skip first 312 audio frames, mapping family 0
    func testEspressif_opus() {
        play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.opus"))
    }
    
    // kAudioFileStreamProperty_DataFormat using source format audio lpcm 2 ch 44100 Hz pcmInt16 interleaved
    // sometimes crashes on real iPhone SE 1st on Stopping. Cause: "Someone is deleting an AudioConverter while it is in use."
    func testEspressif_wav__sometimesFailesOnCleanup() {
        play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.wav"))
    }


    // ok, kAudioFileStreamProperty_FormatList altering source format to audio aac  2 ch 44100 Hz no pcm interleaved
    func testEspressif_wma() {
        play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.wma"))
    }
    
    
    func test21_playingMusic_48kbps_HEAACv1() {
       play(heaac48kbps_music)
    }

    func test22_playingMusic_48kbps_XHEAAC() {
        play(xheaac48kbps_music)
    }

    
    private func play(_ media:MediaEndpoint) {
        do {
            
            try AudioPlayer.open(for: media, listener: nil) {
                [self] (control) in
                    control.play()
                    sleep(12)
                    control.stop()
                    sleep(1)
                    control.close()
                }
                sleep(14)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
}
