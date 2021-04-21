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

import Foundation



class Metadata {
    
    var combinedTitle: String?
    var icyData: [String:String]?
    var opusComments: [String:String]?
    var ybridMetadata: YbridMetadata?
    
    init(combinedTitle:String) {
        self.combinedTitle = combinedTitle
    }
    
    init(opusComments:[String:String]) {
        self.opusComments = opusComments
    }
    
    init(icyData:[String:String]) {
        self.icyData = icyData
    }
    
    init(ybridMetadata:YbridMetadata) {
        self.ybridMetadata = ybridMetadata
    }
    
    func displayTitle() -> String? {
        
        if let ybrid = ybridMetadata {
            var displayTitle = ""
            let item = ybrid.currentItem
            displayTitle = item.title
            if !item.artist.isEmpty {
                displayTitle += "\nby \(item.artist)"
            }
            return displayTitle
        }
        
        if let opus = opusComments {
            let relevant:[String] = ["ALBUM", "ARTIST", "TITLE"]
            let playout = relevant
                .filter { opus[$0] != nil }
                .map { opus[$0]! }
            let displayTitle = playout.joined(separator: " - ")
            if displayTitle.count > 0 {
                // $ALBUM " - " $ARTIST " - " $TITLE " (" $VERSION ")"
                // TODO version
                return displayTitle
            }
        }
        
        if let icyDictionary = icyData {
            if let streamTitle = icyDictionary["StreamTitle"]?.trimmingCharacters(in: CharacterSet.init(charactersIn: "'")) {
                return streamTitle
            }
        }
        
        if combinedTitle != nil {
            return combinedTitle!
        }
        
        return nil
    }
}
