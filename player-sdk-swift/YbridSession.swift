//
// Session.swift
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

public class YbridSession {
    
    let endpoint:MediaEndpoint
    let factory = ControllerFactory()
    var controller:ApiController?
    var metadata:YbridMetadata? {
        didSet {
            if metadata != oldValue, let metadata = metadata {
                if controller is YbridV2Controller { // just logging
                    (controller as! YbridV2Controller).logMetadata()
                }
                metadataListener?.metadataReady(Metadata(ybridMetadata: metadata))
            }
    }}
    
    weak var metadataListener:MetadataListener? { didSet {
        if let metadata = metadata {
            metadataListener?.metadataReady(Metadata(ybridMetadata: metadata))
        }
    }}
    
    public var playbackUri:String { get {
        return controller?.playbackUri ?? endpoint.uri
    }}

    init(on endpoint:MediaEndpoint) {
        self.endpoint = endpoint
    }
    
    func connect() throws {
        self.controller = try factory.create(self)
        try self.controller?.connect()
    }
    
    public func close() {
        self.controller?.disconnect()
    }
    
    func fetchMetadata() {
        if controller is YbridV2Controller {
            (controller as! YbridV2Controller).info()
        }
    }
    
}
