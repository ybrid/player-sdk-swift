//
// MediaEndpoint.swift
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

// MediaEndpoint represents the entry point on a media server.
// It's used to open a session for a stream.

import Foundation

public class MediaEndpoint : Equatable, Hashable {
    public static func == (lhs: MediaEndpoint, rhs: MediaEndpoint) -> Bool {
        return lhs.uri == rhs.uri
    }
    public var hashValue: Int { return uri.hashValue}
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uri)
    }
    
    public let uri:String
    var forcedProtocol:MediaProtocol?

    public init(mediaUri:String!) {
        self.uri = mediaUri
    }
    
    public func forceProtocol(_ mediaProtocol:MediaProtocol) -> MediaEndpoint{
        self.forcedProtocol = mediaProtocol
        return self
    }
}

