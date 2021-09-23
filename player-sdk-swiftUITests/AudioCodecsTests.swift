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

//  from  https://docs.espressif.com/projects/esp-adf/en/latest/design-guide/audio-samples.html
    
    
    //    OK
//    2021-09-21 17:16:06.507628+0200 player-sdk-swiftMacTests-Runner[2184:78408] [loading] AudioDecoderFactory.createDecoder-44 mimeType application/octet-stream resolved to system audio decoder with hint kAudioFileMPEG4Type
//    kAudioFileStreamProperty_FileFormat adts unused
//    kAudioFileStreamProperty_MagicCookieData unused
//    kAudioFileStreamProperty_FormatList entry is audio aac  2 ch 44100 Hz no pcm interleaved
//    kAudioFileStreamProperty_FormatList altering source format to audio aac  2 ch 44100 Hz no pcm interleaved
//    kAudioFileStreamProperty_DataOffset 0 unused
//    kAudioFileStreamProperty_ReadyToProducePackets unused
        func testEspressif_aac() {
            play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.aac"))
        }
        
    //    ok
//    mimeType application/octet-stream resolved to system audio decoder
//    kAudioFileStreamProperty_MagicCookieData unused
//    kAudioFileStreamProperty_FileFormat ac-3 unused
//    kAudioFileStreamProperty_DataFormat using source format audio ac-3 2 ch 44100 Hz no pcm interleaved
//    kAudioFileStreamProperty_FormatList entry is audio ac-3 2 ch 44100 Hz no pcm interleaved
//    kAudioFileStreamProperty_ChannelLayout unused
//    kAudioFileStreamProperty_DataOffset 0 unused
//    kAudioFileStreamProperty_ReadyToProducePackets unused
        func testEspressif_ac3() {
            play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.ac3"))
        }
        
    //    ok
//    mimeType audio/mpeg resolved to system audio decoder with hint kAudioFileMP3Type
    
//  kAudioFileStreamProperty_BitRate 127999 unused
//  kAudioFileStreamProperty_AudioDataByteCount 2993841 unused
//  kAudioFileStreamProperty_AudioDataPacketCount 7163 unused
//  kAudioFileStreamProperty_PacketTableInfo unused
//  kAudioFileStreamProperty_FileFormat MPG3 unused
//    kAudioFileStreamProperty_DataFormat using source format audio .mp3 2 ch 44100 Hz no pcm interleaved
//  kAudioFileStreamProperty_DataOffset 508 unused
//  kAudioFileStreamProperty_ReadyToProducePackets unuse
        func testEspressif_mp3() {
            play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.mp3"))
        }
        
        
    //    ok
//    mimeType application/octet-stream resolved to system audio decoder
//    kAudioFileStreamProperty_FileFormat AIFC unused
//    kAudioFileStreamProperty_DataFormat using source format audio lpcm 2 ch 44100 Hz pcmInt16 interleaved
// kAudioFileStreamProperty_AudioDataByteCount 33002080 unused
// kAudioFileStreamProperty_DataOffset 72 unused
// kAudioFileStreamProperty_AudioDataPacketCount 8250520 unused
// kAudioFileStreamProperty_ReadyToProducePackets unused
        func testEspressif_aiff() {
            play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.aiff"))
        }
        
    //    ok
//    mimeType application/octet-stream resolved to system audio decoder
    
//    kAudioFileStreamProperty_FileFormat flac unused
//    kAudioFileStreamProperty_DataFormat using source format audio flac 2 ch 44100 Hz no pcm interleaved
//    kAudioFileStreamProperty_AudioDataPacketCount 1791 unused
//    kAudioFileStreamProperty_MagicCookieData unused
//    kAudioFileStreamProperty_InfoDictionary unused
//    kAudioFileStreamProperty_DataOffset 8519 unused
//    kAudioFileStreamProperty_ChannelLayout unused
//    kAudioFileStreamProperty_MaximumPacketSize 16823 unused
//    kAudioFileStreamProperty_ReadyToProducePackets true unused
        func testEspressif_flac() {
            play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.flac"))
        }
        
    //    fails
    //    mimeType audio/x-m4a resolved to system audio decoder with hint kAudioFileMPEG4Type
    //    kAudioFileStreamProperty_FileFormat m4af unused
        // 2021-09-21 16:46:07.586683+0200 app-example-ios[1293:35035] [] AudioPlayer.notify-252 fatal 525 DecoderError.failedPackaging, cause: 412 AudioDataError.parsingFailed, OSStatus=1869640813, It is not possible to produce output packets because the file's packet table or other defining info is either not present or is after the audio data.
        func testEspressif_m4a() {
            play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.m4a").forceProtocol(.plain))
        }
        
    
    
        func testM4a() {
            play(MediaEndpoint(mediaUri:
            "https://filesamples.com/samples/audio/m4a/sample2.m4a").forceProtocol(.plain))
        }
    
        // fails
    //  mimeType video/mp4 resolved to system audio decoder with hint kAudioFileMPEG4Type
    //  kAudioFileStreamProperty_FileFormat mp4f unused
        // 2021-09-21 16:47:00.497239+0200 app-example-ios[1312:36539] [] AudioPlayer.notify-252 fatal 525 DecoderError.failedPackaging, cause: 412 AudioDataError.parsingFailed, OSStatus=1869640813, It is not possible to produce output packets because the file's packet table or other defining info is either not present or is after the audio data.
        func testEspressif_mp4() {
            play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.mp4"))
        }
        
        
//        fails
//    mimeType audio/ogg with filename Optional("ff-16b-2c-44100hz.ogg") resolved to opus decoder
        // no stream for  -1265036395 on page 0
//    bis page 186
        func testEspressif_ogg() {
            play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.ogg"))
        }

        // ok
//    mimeType application/octet-stream with filename Optional("ff-16b-2c-44100hz.opus") resolved to opus decoder
    //  OpusData.mapOpusPacket-207 bos opus packet 0
    //  OpusData.onOpusHead-221 OpusHead ver 1, ch 2, skip first 312 audio frames, mapping family 0
        func testEspressif_opus() {
            play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.opus"))
        }
        
        // ok
//
//    kAudioFileStreamProperty_FileFormat WAVE unused
//    kAudioFileStreamProperty_DataFormat using source format audio lpcm 2 ch 44100 Hz pcmInt16 interleaved
//    kAudioFileStreamProperty_AudioDataByteCount 33002080 unused
//    kAudioFileStreamProperty_DataOffset 46 unused
//    kAudioFileStreamProperty_AudioDataPacketCount 8250520 unused
//    kAudioFileStreamProperty_ReadyToProducePackets unused
        func testEspressif_wav() {
            play(MediaEndpoint(mediaUri: "https://dl.espressif.com/dl/audio/ff-16b-2c-44100hz.wav"))
        }


        // ok,
//    mimeType application/octet-stream resolved to system audio decoder
//    kAudioFileStreamProperty_FileFormat adts unused
//    kAudioFileStreamProperty_MagicCookieData unused
//    kAudioFileStreamProperty_FormatList entry is audio aac  2 ch 44100 Hz no pcm interleaved
//    kAudioFileStreamProperty_FormatList altering source format to audio aac  2 ch 44100 Hz no pcm interleaved
//    kAudioFileStreamProperty_DataOffset 0 unused
//    kAudioFileStreamProperty_ReadyToProducePackets unused
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
                
                try AudioPlayer.open(for: media.forceProtocol(.plain), listener: nil) {
                    [self] (control) in
                        control.play()
                        sleep(12)
                        control.stop()
                    }
                    sleep(14)
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        
}
