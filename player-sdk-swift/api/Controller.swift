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

protocol Controller {
    var playbackUri:String { get }
    var connected:Bool { get }
}

class ApiController : Controller {
    
    let apiVersion:ControllerVersion
    let session:YbridSession
    var baseUrl:URL
    var playbackUri:String
    var valid:Bool = true
    var connected:Bool = false { didSet {
        Logger.api.info("\(apiVersion) controller \(connected ? "connected" : "disconnected")")
    }}

    init(session:YbridSession, version:ControllerVersion) {
        self.apiVersion = version
        self.session = session
        self.playbackUri = session.endpoint.uri
        self.baseUrl = URL(string: session.endpoint.uri)!

    }
    
    func connect() throws {}
    func disconnect() {}

}
