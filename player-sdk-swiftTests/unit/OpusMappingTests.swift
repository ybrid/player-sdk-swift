//
// OpusHeaderTests.swift
// player-sdk-swiftTests
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

class OpusMappingTests: XCTestCase {

    
    let package1:Data = "4f 67 67 53  00 02 00 00  00 00 00 00  00 00 ce df  46 2e 00 00  00 00 3f bc  59 ae 01 13      4f 70 75 73  48 65 61 64  01 02 38 01  80 bb 00 00  00 00 00 4f  67 67 53 00  00 00 00 00  00 00 00 00   00 ce df 46  2e 01 00 00  00 e9 82 42  43 01 2f 4f  70 75 73 54 61 67 73 1e 00 00 00 45 6e 63 6f 64 65 64 20 77 69 74 68 20 47 53 74 72 65 61 6d 65 72 20 6f 70 75 73 65 6e 63 00 00 00 00 01".hexadecimal!
    
    let package2:Data = "4f 67 67 53 00 02 00 00 00 00 00 00 00 00 e5 7c c5 3a 00 00 00 00 71 01 73 56 01 13 4f 70 75 73 48 65 61 64 01 02 38 01 80 bb 00 00 00 00 00 4f 67 67 53 00 00 00 00 00 00 00 00 00 00 e5 7c c5 3a 01 00 00 00 2c 7d 90 81 01 2f 4f 70 75 73 54 61 67 73 1e 00 00 00 45 6e 63 6f 64 65 64 20 77 69 74 68 20 47 53 74 72 65 61 6d 65 72 20 6f 70 75 73 65 6e 63 00 00 00 00 01".hexadecimal!
    
    
    let package3 = " 4f 67 67 53 00 02 00 00 00 00 00 00 00 00 e5 7c c5 3a 00 00 00 00 71 01 73 56 01 13 4f 70 75 73 48 65 61 64 01 02 38 01 80 bb 00 00 00 00 00 4f 67 67 53 00 00 00 00 00 00 00 00 00 00 e5 7c c5 3a 01 00 00 00 2c 7d 90 81 01 2f 4f 70 75 73 54 61 67 73 1e 00 00 00 45 6e 63 6f 64 65 64 20 77 69 74 68 20 47 53 74 72 65 61 6d 65 72 20 6f 70 75 73 65 6e 63 00 00 00 00 01".hexadecimal!
    
    let package4 = " 4f 70 75 73 54 61 67 73 11 00 00 00 6c 69 62 6f 70 75 73 20 31 2e 30 2e 31 2d 72 63 33 08 00 00 00 25 00 00 00 45 4e 43 4f 44 45 52 3d 6f 70 75 73 65 6e 63 20 66 72 6f 6d 20 6f 70 75 73 2d 74 6f 6f 6c 73 20 30 2e 31 2e 35 13 00 00 00 61 72 74 69 73 74 3d 45 68 72 65 6e 20 53 74 61 72 6b 73 12 00 00 00 74 69 74 6c 65 3d 50 61 70 65 72 20 4c 69 67 68 74 73 17 00 00 00 61 6c 62 75 6d 3d 4c 69 6e 65 73 20 42 75 69 6c 64 20 57 61 6c 6c 73 0f 00 00 00 64 61 74 65 3d 32 30 30 35 2d 30 39 2d 30 35 25 00 00 00 63 6f 70 79 72 69 67 68 74 3d 43 6f 70 79 72 69 67 68 74 20 32 30 30 35 20 45 68 72 65 6e 20 53 74 61 72 6b 73 39 00 00 00 6c 69 63 65 6e 73 65 3d 68 74 74 70 3a 2f 2f 63 72 65 61 74 69 76 65 63 6f 6d 6d 6f 6e 73 2e 6f 72 67 2f 6c 69 63 65 6e 73 65 73 2f 62 79 2d 6e 63 2d 73 61 2f 31 2e 30 2f 1a 00 00 00 6f 72 67 61 6e 69 7a 61 74 69 6f 6e 3d 6d 61 67 6e 61 74 75 6e 65 2e 63 6f 6d".hexadecimal!
    
//    let headPackage = "".hexadecimal!
//    let tagsPackage = "".hexadecimal!
    
    var opusHead:OpusHead?
    var opusTags:OpusTags?
    
    
    override func setUpWithError() throws {
        let headTestPackage = package1
        print("------ using data:")
        print(headTestPackage.stringDump)
        let found:Range<Data.Index> = headTestPackage.range(of: Data("OpusHead".utf8))!
        print("OpusHead begins at index \(found.startIndex)")
        let opusHeadData = Data(headTestPackage[found.startIndex..<headTestPackage.count])
        print("------")

        opusHead = OpusHead(package: opusHeadData)
        print(opusHead.debugDescription)
        print("------")
        print("------")
        
        let tagsTestPackage = package4
        let foundTags:Range<Data.Index> = tagsTestPackage.range(of: Data("OpusTags".utf8))!
        print("OpusTags begins at index \(foundTags.startIndex)")
        let opusTagsData = Data(tagsTestPackage[foundTags.startIndex..<tagsTestPackage.count])
        opusTags = OpusTags(package: opusTagsData)
        print(opusTags.debugDescription)
        print("------")
    }

    override func tearDownWithError() throws {
    }
    
    func testVersion() throws {
        XCTAssertEqual(1, opusHead?.version)
    }
    func testChannels() throws {
        XCTAssertEqual(2, opusHead?.outChannels)
    }
    func testPreSkip() throws {
        XCTAssertEqual(312, opusHead?.preSkip)
    }
    func testMappingFamiliy() throws {
        XCTAssertEqual(0, opusHead?.mappingFamily)
    }
    func testDebugDescription() {
        print((opusHead?.debugDescription)!)
    }

    func testVendorString() {
        XCTAssertEqual("libopus 1.0.1-rc3", opusTags?.vendorString)
    }

    func testComments() {
        guard let comments = opusTags?.comments else {
            XCTFail()
            return
        }
        XCTAssertEqual(8, comments.count)
        print (comments)
        XCTAssertEqual("Paper Lights", comments["TITLE"])
        XCTAssertEqual("Ehren Starks", comments["ARTIST"])
        XCTAssertEqual("opusenc from opus-tools 0.1.5",comments["ENCODER"])
    }
}


extension String {

    /// Create `Data` from hexadecimal string representation
    ///
    /// This creates a `Data` object from hex string. Note, if the string has any spaces or non-hex characters (e.g. starts with '<' and with a '>'), those are ignored and only hex characters are processed.
    ///
    /// - returns: Data represented by this hexadecimal string.

    var hexadecimal: Data? {
        var data = Data(capacity: count / 2)

        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self)) { match, _, _ in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }

        guard data.count > 0 else { return nil }

        return data
    }

}

extension Data {
    var hexDump: String {
        let dump = reduce("") { $0 + String(format: "%02x ", $1)}
        let count = subStringCount(dump, " ")
        return "\(count) bytes are \(dump)"
    }
    
    var stringDump: String {
        let dump = reduce("") { $0 + String(format: "%c", $1)}
        let oggCount = subStringCount(dump, "Ogg")
        return "\(count) bytes are '\(dump)' --> 'Ogg' \(oggCount)"
    }
    
    private func subStringCount(_ inString: String, _ substr: String) -> Int {
        if inString.isEmpty { return 0 }
        return inString.components(separatedBy: substr).count - 1
    }
}

