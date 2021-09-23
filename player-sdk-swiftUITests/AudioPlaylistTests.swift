//
// AudioPlaylistTests.swift
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

class AudioPlaylistTests: XCTestCase {
    
//    var playlistEndpoints:[MediaEndpoint] = []
    
    override func setUpWithError() throws {
//        playlistEndpoints = try readPlaylist("ff-16b-1c-playlist")
//            "https://dl.espressif.com/dl/audio/ff-16b-1c-playlist.m3u&raw=true")

    }

    func testEspressif_codecsPlaylist() throws {
        let playlistEndpoints = try readPlaylist("ff-16b-1c-playlist")
        for endpoint in playlistEndpoints {
            print( "play \(endpoint.uri)" )
            play(endpoint.forceProtocol(.plain))
        }
    }
    
    func testEspressif_mp3Playlist() throws {
        let playlistEndpoints = try readPlaylist("ff-16b-mp3-playlist")
        for endpoint in playlistEndpoints {
            print( "play \(endpoint.uri)" )
            play(endpoint.forceProtocol(.plain))
        }
    }
    
   
    private func play(_ media:MediaEndpoint) {
        do {
            try AudioPlayer.open(for: media, listener: nil) {
                (control) in
                    control.play()
                    sleep(12)
                    control.stop()
                }
                sleep(14)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }
    
    private func readPlaylist(_ from: String) throws -> [MediaEndpoint] {
        let lines = try readLinesFromFile(from)
        print(lines)
        return lines.map{ MediaEndpoint(mediaUri:$0) }
    }
    
    private func readLinesFromFile(_ filename:String) throws -> [String] {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: filename, withExtension: "m3u") else {
            return []
        }
        let contents = try String(contentsOf: url)
        return lines(contents)
    }
    
    private func lines(_ content:String) -> [String] {
        let dataArray = content.components(separatedBy: "\n")
            var lines:[String] = []
        for line in dataArray {
            if line.starts(with: "#") || line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            lines.append(line.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return lines
    }
    
}
