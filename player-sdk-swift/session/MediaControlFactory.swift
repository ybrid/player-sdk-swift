//
// ApiDriverFactory.swift
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


public enum MediaProtocol : String {
    case plain // http only
    case icy // http with icy-fields
    case ybridV2 = "v2" // ybrid verson 2 (with icy-fields)
}

class MediaControlFactory {
    
    func create(_ session:MediaSession) throws -> (MediaDriver,MediaState) {
        let apiVersion:MediaProtocol
        if let forced = session.endpoint.forcedProtocol {
            apiVersion = forced
        } else {
            let uri = session.endpoint.uri
            apiVersion = try getVersion(uri)
        }
        let driver:MediaDriver
        let state:MediaState
        switch apiVersion {
        case .plain, .icy:
            let iState = IcyState(endpoint: session.endpoint)
            let iDriver = IcyDriver(icyState: iState)
            state = iState
            driver = iDriver
        case .ybridV2:
            let yState = YbridState(endpoint: session.endpoint)
            let yDriver = YbridV2Driver(ybridState: yState, notifyError: session.notifyError)
            state = yState
            driver = yDriver
        }
        Logger.session.notice("selected media protocol is \(apiVersion)")
        return (driver,state)
    }
    
    // visible for unit tests
    func getVersion(_ uri:String) throws -> MediaProtocol {
        
        guard let url = URL(string: uri) else {
            throw SessionError(ErrorKind.invalidUri, uri)
        }
        
        let ybridVersions = try getSupportedVersionsFromYbridV2Server(url: url)
        if ybridVersions.contains(MediaProtocol.ybridV2.rawValue) {
            return .ybridV2
        } else {
            return .icy
        }
    }
    
    private func getSupportedVersionsFromYbridV2Server(url: URL) throws -> [String] {
        var versions:[String] = []
        do {
            guard let ybridResponse = try JsonRequest(url: url).performOptionsSync(responseType: YbridResponse.self) else {
                return versions
            }
            let info = ybridResponse.__responseHeader
            Logger.session.debug(String(data: try JSONEncoder().encode(info), encoding: .utf8) ?? "(no ybrid info struct)")
            if !info.success {
                throw SessionError(ErrorKind.invalidResponse, "__responseHeader.success is false")
            }
            if !(200...299).contains(info.statusCode) {
                throw SessionError(ErrorKind.invalidResponse, "__responseHeader.statusCode is \(info.statusCode)")
            }
            versions = ybridResponse.__responseHeader.supportedVersions
        } catch {
            Logger.session.error(error.localizedDescription)
            throw error
        }
        return versions
    }
}
