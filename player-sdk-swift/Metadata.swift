//
// Metadata.swift
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

// Metadata contains data corresponding to a time period or a single instance of a stream.
// The data can origin from different sources. In general it is up to the purpose
// which of the data is relevant.

import Foundation

class Metadata {
    
    private var icyData: [String:String]?
    private var vorbisComments: [String:String]?
    var ybridMetadata: YbridMetadata?
    
    init(vorbisComments:[String:String]) {
        self.vorbisComments = vorbisComments
    }
    init(icyData:[String:String]) {
        self.icyData = icyData
    }
    init(ybridMetadata:YbridMetadata) {
        self.ybridMetadata = ybridMetadata
    }

    func displayTitle() -> String? {
        
        // $TITLE by $ARTIST
        if let ybrid = ybridMetadata {
            let item = ybrid.currentItem
            var displayTitle = item.title
            if !item.artist.isEmpty {
                displayTitle += "\nby \(item.artist)"
            }
            return displayTitle
        }
        
        // $ALBUM - $ARTIST - $TITLE ($VERSION)
        if let comment = vorbisComments {
            let relevant:[String] = ["ALBUM", "ARTIST", "TITLE"]
            let playout = relevant
                .filter { comment[$0] != nil }
                .map { comment[$0]! }
            var displayTitle = playout.joined(separator: " - ")
            if let version = comment["VERSION"] {
                displayTitle += " (\(version))"
            }
            if displayTitle.count > 0 {
              

                return displayTitle
            }
        }
        
        // $ARTIST - $TITLE
        if let icyDictionary = icyData {
            if let streamTitle = icyDictionary["StreamTitle"]?.trimmingCharacters(in: CharacterSet.init(charactersIn: "'")) {
                return streamTitle
            }
        }
        
        return nil
    }
}
