//
// Controller.swift
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

protocol MediaControl {
    var playbackUri: String { get }
    var connected: Bool { get }
    var mediaProtocol: MediaProtocol { get }
}

class MediaDriver : MediaControl {
    
    let mediaProtocol:MediaProtocol
    let session:MediaSession
    var baseUrl:URL
    var playbackUri:String
    var valid:Bool = true //  { get }
    var connected:Bool = false { didSet {
        Logger.controlling.info("\(mediaProtocol) controller \(connected ? "connected" : "disconnected")")
    }}
    var offsetToLiveS:TimeInterval?

    init(session:MediaSession, version:MediaProtocol) {
        self.mediaProtocol = version
        self.session = session
        self.playbackUri = session.endpoint.uri
        self.baseUrl = URL(string: session.endpoint.uri)!
    }
    
    //    func executeRequest(@NotNull Request<Command> request) throws
    func connect() throws {}
    func disconnect() {}

    //    var playoutInfo: PlayoutInfo { get }
    
    //    var capabilities: CapabilitySet { get }
    //    void clearChanged(@NotNull SubInfo what);
    //    func hasChanged(@NotNull SubInfo what) -> Bool
    
    //    func getBouquet() -> Bouquet
    //    @NotNull Service getCurrentService();
}
