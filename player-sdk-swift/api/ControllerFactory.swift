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


enum ControllerVersion : String {
    case plain
    case icy
    case ybridV2 = "v2"
}

protocol ApiControllerOld {
    var apiVersion:ControllerVersion { get }
    var playbackUri:String { get }
    
    //    func executeRequest(@NotNull Request<Command> request) throws
    func connect() throws
    func disconnect()
    var connected:Bool { get }
    var valid:Bool { get }
    
    //    var playoutInfo: PlayoutInfo { get }
    
    //    var capabilities: CapabilitySet { get }
    //    void clearChanged(@NotNull SubInfo what);
    //    func hasChanged(@NotNull SubInfo what) -> Bool
    
    //    func getBouquet() -> Bouquet
    //    @NotNull Service getCurrentService();
}


class ControllerFactory {
    
    func create(_ session:YbridSession) throws -> ApiController {
        let uri = session.endpoint.uri
        let driver:ApiController
        let apiVersion = try getVersion(uri)
        switch apiVersion {
        case .plain, .icy: driver = DummyController(session:session)
        case .ybridV2: driver = YbridV2Controller(session:session)
        }
        Logger.api.notice("selected API version is \(apiVersion)")
        return driver
    }
    
    func getVersion(_ uri:String) throws -> ControllerVersion {
        
        guard let url = URL(string: uri) else {
            throw ApiError(ErrorKind.invalidUri, uri)
        }
        
        let ybridVersions = try getSupportedVersionsFromYbridV2Server(url: url)
        if ybridVersions.contains(ControllerVersion.ybridV2.rawValue) {
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
            Logger.api.debug(String(data: try JSONEncoder().encode(info), encoding: .utf8) ?? "(no ybrid info struct)")
            if !info.success {
                throw ApiError(ErrorKind.invalidResponse, "__responseHeader.success is false")
            }
            if !(200...299).contains(info.statusCode) {
                throw ApiError(ErrorKind.invalidResponse, "__responseHeader.statusCode is \(info.statusCode)")
            }
            versions = ybridResponse.__responseHeader.supportedVersions
        } catch {
            Logger.api.error(error.localizedDescription)
            throw error
        }
        return versions
    }
}
