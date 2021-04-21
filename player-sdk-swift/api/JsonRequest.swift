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
    static let iso8601withMilliSeconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale.current//(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()
}

class JsonRequest {/*: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate*/
    
    static let applicationJson:String = "application/json"
    static let encodingUtf8:String = "utf-8"
    
    let url:URL
    let configuration = URLSessionConfiguration.default
    
    let decoder = JSONDecoder()
    
    init(url:URL) {
        self.url = url
        //        configuration.timeoutIntervalForResource = 5
        //        super.init()
            self.decoder.dateDecodingStrategy = .formatted(Formatter.iso8601withMilliSeconds)
    }
    
    func performOptionsSync<T : Decodable>(responseType: T.Type) throws -> T? {
        
        Logger.api.debug("calling OPTIONS on \(url.absoluteString)")
        
        let semaphore = DispatchSemaphore(value: 0)
        var apiError:ApiError? { didSet {
            semaphore.signal()
        }}
        
        var result:T?
        
        let session = URLSession(configuration: configuration)//, delegate: self, delegateQueue: nil)
        var request = URLRequest(url: url)
        request.httpMethod = "OPTIONS"
        request.setValue(JsonRequest.applicationJson, forHTTPHeaderField: "Accept")
        request.setValue(JsonRequest.encodingUtf8, forHTTPHeaderField: "Accept-Charset")
        
        let task = session.dataTask(with: request) { data, response, error in
            
            do {
                if try !self.isJsonResponse(response) {
                    semaphore.signal()
                    return
                }
            } catch {
                if error is ApiError {
                    apiError = error as? ApiError
                } else {
                    apiError = ApiError(ErrorKind.invalidResponse, "error reading json", error)
                }
                return
            }
            
            if let error = error {
                apiError = ApiError(ErrorKind.unknown, "error in OPTIONS \(self.url.absoluteString)", error)
                return
            }
            
            guard let data = data else {
                apiError = ApiError(ErrorKind.invalidResponse,"missing data")
                return
            }
            
            if Logger.verbose, let dataString = String(data: data, encoding: .utf8) {
                Logger.api.debug("parsing \(dataString) into \(responseType)")
            }
            
            do {
                result = try self.decoder.decode(responseType, from: data)
                semaphore.signal()
            } catch {
                apiError = ApiError(ErrorKind.invalidResponse, "error parsing \(data.debugDescription) into \(responseType)", error)
                return
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: .distantFuture)
        
        if task.state != URLSessionDataTask.State.completed {
            Logger.api.notice("cancelling task in state \(describe(task.state))")
            task.cancel()
        }
        
        if apiError != nil {
            throw apiError!
        }
        
        return result
    }
    
    
    func performPostSync<T : Decodable>(responseType: T.Type) throws -> T? {
        
        Logger.api.debug("calling POST on \(url.absoluteString)")
        
        let semaphore = DispatchSemaphore(value: 0)
        var apiError:ApiError? { didSet {
            semaphore.signal()
        }}
        
        var result:T?
        
        let session = URLSession(configuration: URLSessionConfiguration.default)//, delegate: self, delegateQueue: nil)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(JsonRequest.applicationJson, forHTTPHeaderField: "Accept")
        request.setValue(JsonRequest.encodingUtf8, forHTTPHeaderField: "Accept-Charset")
        
        let task = session.dataTask(with: request) { data, response, error in
            
            if let noJsonError = self.validateJsonResponse(response) {
                apiError = noJsonError
                return
            }
            if let error = error {
                apiError = ApiError(ErrorKind.serverError, "error in POST \(self.url.absoluteString)", error)
                return
            }
            
            guard let data = data else {
                apiError = ApiError(ErrorKind.invalidResponse, "missing data")
                return
            }
            
            if Logger.verbose, let dataString = String(data: data, encoding: .utf8) {
                Logger.api.debug("parsing \(dataString) into \(responseType)")
            }
            
            do {
                result = try self.decoder.decode(responseType, from: data)
                semaphore.signal()
            } catch {
                apiError = ApiError(ErrorKind.invalidResponse, "error parsing \(data.debugDescription) into \(responseType)", error)
                return
            }
        }
        task.resume()
        _ = semaphore.wait(timeout: .distantFuture)
        
        if task.state != URLSessionDataTask.State.completed {
            Logger.api.notice("cancelling task in state \(describe(task.state))")
            task.cancel()
        }
        
        if apiError != nil {
            throw apiError!
        }
        
        return result
    }
    
    
    private func validateJsonResponse(_ response: URLResponse?) -> ApiError? {
        
        if let response = response {
            Logger.api.debug("mime is \(String(describing: response.mimeType)), expected length is \(response.expectedContentLength)")
        }
        
        guard let mime = response?.mimeType, mime == JsonRequest.applicationJson else {
            return ApiError(ErrorKind.missingMimeType, "missing mime type \(JsonRequest.applicationJson)")
        }
        guard let length = response?.expectedContentLength, length > 0 else {
            return ApiError(ErrorKind.invalidData, "content length not > 0")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.api.error(response.debugDescription)
            return ApiError(ErrorKind.serverError, "no http response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            return ApiError(ErrorKind.serverError, "http status \(httpResponse.statusCode)")
        }
        
        let headers = httpResponse.allHeaderFields
        guard let type = headers["Content-Type"] as? String else {
            return ApiError(ErrorKind.invalidResponse,"missing Content-Type")
        }
        guard type.lowercased() == JsonRequest.applicationJson else {
            return ApiError(ErrorKind.missingMimeType,"unsupported Content-Type \(type)")
        }
        guard let encoding = headers["Content-Encoding"] as? String else {
            return ApiError(ErrorKind.invalidResponse,"missing Content-Encoding")
        }
        guard encoding.lowercased() == JsonRequest.encodingUtf8 else {
            return ApiError(ErrorKind.invalidResponse, "unsupported Content-Encoding \(encoding)")
        }
        return nil
    }
    
    private func isJsonResponse(_ response: URLResponse?) throws -> Bool {
        
        guard let httpResponse = response as? HTTPURLResponse else {
            Logger.api.error(response.debugDescription)
            throw ApiError(ErrorKind.serverError, "no http response")
        }
        
        guard httpResponse.mimeType == JsonRequest.applicationJson else {
            return false
        }
        guard httpResponse.expectedContentLength > 0 else {
            return false
        }
        
        let headers = httpResponse.allHeaderFields
        guard let type = headers["Content-Type"] as? String,
              type.lowercased().contains(JsonRequest.applicationJson) else {
            return false
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            Logger.api.debug("http status \(httpResponse.statusCode)")
            return false
        }
        
        //        guard let encoding = headers["Content-Encoding"] as? String else {
        //            return ApiError(ErrorKind.invalidResponse,"missing Content-Encoding")
        //        }
        //        guard encoding.lowercased() == JsonRequest.encodingUtf8 else {
        //            return ApiError(ErrorKind.invalidResponse, "unsupported Content-Encoding \(encoding)")
        //        }
        return true
    }
    
    
    // MARK: URLSessionTaskDelegate
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        Logger.api.notice("follow redirect: \(response.description)")
        task.cancel()
    }
    
    
    //    @available(iOS 11.0, *)
    //    func urlSession(_ session: URLSession, task: URLSessionTask, willBeginDelayedRequest request: URLRequest, completionHandler: @escaping (URLSession.DelayedRequestDisposition, URLRequest?) -> Void) {
    //        Logger.api.notice()
    //    }
    
    
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        Logger.api.notice()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        Logger.api.notice()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, needNewBodyStream completionHandler: @escaping (InputStream?) -> Void) {
        Logger.api.notice()
    }
    
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        Logger.api.notice()
    }
    
    
    //    @available(iOS 10.0, *)
    //    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
    //        Logger.api.notice()
    //    }
    
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Logger.api.notice()
    }
    
    // MARK: URLSessionDataDelegate
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        Logger.api.notice("didReceive response for task \(dataTask.taskIdentifier)")
        
        completionHandler(Foundation.URLSession.ResponseDisposition.allow)
    }
    
    
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome downloadTask: URLSessionDownloadTask) {
        Logger.api.notice()
    }
    
    
    //    @available(iOS 9.0, *)
    //    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didBecome streamTask: URLSessionStreamTask){
    //        Logger.api.notice()
    //    }
    
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        Logger.api.notice()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        Logger.api.notice()
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
