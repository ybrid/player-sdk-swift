//
// JsonRequest.swift
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

extension Formatter {
    static let iso8601withMillis: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()
    static let iso8601NoMillis: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return formatter
    }()
}

extension JSONDecoder.DateDecodingStrategy {
    static let flexMillisIso8601 = custom {
        let container = try $0.singleValueContainer()
        let jsonString = try container.decode(String.self)
        if let date = Formatter.iso8601withMillis.date(from: jsonString) {
            return date
        }
        if let date = Formatter.iso8601NoMillis.date(from: jsonString) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "corrupted date: \(jsonString)")
    }
}

class JsonRequest {
    
    static let applicationJson:String = "application/json"
    static let encodingUtf8:String = "utf-8"
    static let onlyPostfix = ", */*; q=0"
    
    let url:URL
    let configuration = URLSessionConfiguration.default
    
    let decoder = JSONDecoder()
    
    init(url:URL) {
        self.url = url
        configuration.timeoutIntervalForResource = 3
        configuration.timeoutIntervalForRequest = 3
        self.decoder.dateDecodingStrategy = JSONDecoder.DateDecodingStrategy.flexMillisIso8601
    }
    
    func performOptionsSync<T : Decodable>(responseType: T.Type) throws -> T? {
        
        Logger.session.debug("calling OPTIONS on \(url.absoluteString)")
        
        let semaphore = DispatchSemaphore(value: 0)
        var apiError:SessionError? { didSet {
            semaphore.signal()
        }}
        
        var result:T?
        
        let session = URLSession(configuration: configuration)
        var request = URLRequest(url: url)
        request.httpMethod = "OPTIONS"
        request.setValue(JsonRequest.applicationJson + JsonRequest.onlyPostfix, forHTTPHeaderField: "Accept")
        request.setValue(JsonRequest.encodingUtf8 + JsonRequest.onlyPostfix, forHTTPHeaderField: "Accept-Charset")
        
        let task = session.dataTask(with: request) { data, response, error in

            if let error = error {
                let optionsState = OptionsTaskState.getOptionsState(error)
                if optionsState.severity == ErrorSeverity.notice {
                    if Logger.verbose { Logger.session.debug(error.localizedDescription) }
                    semaphore.signal()
                    return
                }
  
                apiError = SessionError(ErrorKind.serverError, optionsState)
                return
            }
           
            if let apiError = self.validateJsonResponse(response) {
                if Logger.verbose { Logger.session.debug(apiError.localizedDescription) }
                semaphore.signal()
                return
            }
            
            guard let data = data else {
                apiError = SessionError(ErrorKind.invalidResponse, "missing data")
                return
            }
            
            if Logger.verbose, let dataString = String(data: data, encoding: .utf8) {
                Logger.session.debug("parsing \(dataString) into \(responseType)")
            }
            
            do {
                result = try self.decoder.decode(responseType, from: data)
                semaphore.signal()
            } catch {
                guard let dataString = String(data: data, encoding: .utf8) else {
                    apiError = SessionError(ErrorKind.invalidResponse, "error parsing \(data.debugDescription) into \(responseType)", error)
                    return
                }
                apiError = SessionError(ErrorKind.invalidResponse, "error parsing \(dataString) into \(responseType)", error)
                return
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: .distantFuture)
        
        if task.state != URLSessionDataTask.State.completed {
            Logger.session.notice("cancelling task in state \(describe(task.state))")
            task.cancel()
        }
        
        if apiError != nil {
            throw apiError!
        }
        
        return result
    }
    
    
    func performPostSync<T : Decodable>(responseType: T.Type) throws -> T? {
        
        Logger.session.debug("calling POST on \(url.absoluteString)")
        
        let semaphore = DispatchSemaphore(value: 0)
        var apiError:SessionError? { didSet {
            semaphore.signal()
        }}
        
        var result:T?
        
        let session = URLSession(configuration: configuration)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(JsonRequest.applicationJson + JsonRequest.onlyPostfix, forHTTPHeaderField: "Accept")
        request.setValue(JsonRequest.encodingUtf8 + JsonRequest.onlyPostfix, forHTTPHeaderField: "Accept-Charset")
        
        let task = session.dataTask(with: request) { data, response, error in
            
            if let noJsonError = self.validateJsonResponse(response) {
                apiError = noJsonError
                return
            }
            if let error = error {
                apiError = SessionError(ErrorKind.serverError, "error in POST \(self.url.absoluteString)", error)
                return
            }
            
            guard let data = data else {
                apiError = SessionError(ErrorKind.invalidResponse, "missing data")
                return
            }
            
            if Logger.verbose, let dataString = String(data: data, encoding: .utf8) {
                Logger.session.debug("parsing \(dataString) into \(responseType)")
            }
            
            do {
                result = try self.decoder.decode(responseType, from: data)
                semaphore.signal()
            } catch {
                guard let dataString = String(data: data, encoding: .utf8) else {
                    apiError = SessionError(ErrorKind.invalidResponse, "error parsing \(data.debugDescription) into \(responseType)", error)
                    return
                }
                apiError = SessionError(ErrorKind.invalidResponse, "error parsing \(dataString) into \(responseType)", error)
                return
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: .distantFuture)
        
        if task.state != URLSessionDataTask.State.completed {
            Logger.session.notice("cancelling task in state \(describe(task.state))")
            task.cancel()
        }
        
        if apiError != nil {
            throw apiError!
        }
        
        return result
    }
    
    
    private func validateJsonResponse(_ response: URLResponse?) -> SessionError? {
        
        if let response = response {
            if Logger.verbose { Logger.session.debug("mime is \(String(describing: response.mimeType)), expected length is \(response.expectedContentLength)") }
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.session.error(response.debugDescription)
            return SessionError(ErrorKind.serverError, "no http response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            return SessionError(ErrorKind.serverError, "http status \(httpResponse.statusCode)")
        }
        
        guard let mime = response?.mimeType, mime == JsonRequest.applicationJson else {
            return SessionError(ErrorKind.missingMimeType, "missing mime type \(JsonRequest.applicationJson)")
        }
        guard let length = response?.expectedContentLength, length > 0 else {
            return SessionError(ErrorKind.invalidData, "content length not > 0")
        }
        

        
        let headers = httpResponse.allHeaderFields
        guard let type = headers["Content-Type"] as? String else {
            return SessionError(ErrorKind.invalidResponse,"missing Content-Type")
        }
        guard type.lowercased().contains(JsonRequest.applicationJson) else {
            return SessionError(ErrorKind.missingMimeType,"unsupported Content-Type \(type)")
        }
        return nil
    }
}

fileprivate func describe(_ state: URLSessionTask.State? ) -> String {
    guard let state = state else {
        return "(nil)"
    }
    switch state {
    case .suspended: return "suspended"
    case .running : return "running"
    case .canceling: return "canceling"
    case .completed: return "completed"
    default: return "(unknown)"
    }
}
