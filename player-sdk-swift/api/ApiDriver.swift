//
// ApiDriver.swift
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



enum ApiVersion : String {
    case plain
    case icy
    case ybridV2 = "v2"
}

class ApiDriver {
    
    
    let endpoint:MediaEndpoint
    init(_ endpoint:MediaEndpoint){
        self.endpoint = endpoint
    }
    
    func getVersion() -> ApiVersion {
        let ybridVersions = getSupportedVersionsFromYbridV2Server()
        if ybridVersions.contains(ApiVersion.ybridV2.rawValue) {
            return .ybridV2
        }
        return .icy
    }
    
    struct YbridResponse: Decodable {
        let __responseHeader: YbridInfo
    }
    struct YbridInfo: Decodable {
        let responseVersion: String
        let statusCode: Int
        let success: Bool
        let supportedVersions: [String]
//        let timestamp: Date // TODO
    }
    
    private func getSupportedVersionsFromYbridV2Server() -> [String] {
        var versions:[String] = []
        if var url = URL(string: endpoint.uri) {
            url = url.appendingPathComponent("ctrl/v2/session/info")
            var request = URLRequest(url: url)
            request.httpMethod = "OPTIONS"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("utf-8", forHTTPHeaderField: "Accept-Charset")
            let semaphore = DispatchSemaphore(value: 0)
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let httpResponse = response as? HTTPURLResponse {
                    print("status \(httpResponse.statusCode)")
                    let headers = httpResponse.allHeaderFields
                    let encoding = headers["Content-Encoding"]
                    print("encoding \(encoding)")
                    let type = headers["Content-Type"]
                    print("type \(type)")
                }
                
                if let data = data, let dataString = String(data: data, encoding: .utf8) {
                    print(dataString)
                    do {
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        let ybridResponse: YbridResponse = try decoder.decode(YbridResponse.self, from: data)
                        print(ybridResponse)
                        versions = ybridResponse.__responseHeader.supportedVersions

                    } catch let error {
                       print(error)
                    }
                }
                semaphore.signal()
   
               }.resume()
            _ = semaphore.wait(timeout: .distantFuture)
        }
        return versions
    }
    
    
    func connect(url:URL) throws {
        
    }
    
}
