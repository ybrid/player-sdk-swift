//
// ApiError.swift
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

class ApiError : AudioPlayerError {
    
    
    init(_ kind:ErrorKind, _ message:String, _ cause:Error? = nil) {
        super.init(kind, message, cause)
    }
    
    init(_ kind:ErrorKind, _ cause:OptionsTaskState) {
        super.init(kind, cause.message, cause)
        super.osstatus = cause.osstatus
    }
    
}
    
    
class OptionsTaskState : Equatable, LocalizedError {
        
        static func == (lhs: OptionsTaskState, rhs: OptionsTaskState) -> Bool {
            return lhs.osstatus == rhs.osstatus
        }
        
        private static let completed = OptionsTaskState(0, "completed", .notice) /// loading finished
        
        private static var knownErrorStates: [OptionsTaskState] = [
            completed,
            OptionsTaskState(-1001, "timed out", .notice), /// timeout fallback
            OptionsTaskState(-1005, "connection lost", .notice),
            
            OptionsTaskState(-1000, "bad url", .fatal),
            OptionsTaskState(-1002, "unsupported url", .fatal),
            OptionsTaskState(-1004, "could not connect", .fatal),
            OptionsTaskState(-1022, "not https", .fatal),
            OptionsTaskState(-1100, "url not found", .fatal),

            OptionsTaskState(-1200, "cannot connect over ssl",.fatal),
            
            OptionsTaskState(-1003, "host not found", .fatal),
            OptionsTaskState(-1009, "offline?", .fatal),



            OptionsTaskState(-997, "lost connection in background", .fatal) //  App in den Hingerund  -->  -997 Lost connection to background transfer service
        ]

        let osstatus:OSStatus
        let message:String
        let severity:ErrorSeverity
  
        init(_ code:OSStatus, _ message:String, _ severity:ErrorSeverity) {
            self.osstatus = code
            self.message = message
            self.severity = severity
        }
        
        public var errorDescription: String? {
            var description = String(format:"%@ OSStatus=%d", "\(type(of: self))", osstatus)
            description += ", " + message
            return description
        }
        
        static func getOptionsState(_ error: Error) -> OptionsTaskState {
            let nserr = error as NSObject
            let code = nserr.value(forKey: "code") as! NSNumber.IntegerLiteralType
            let message = String(format: "OSStatus=%d %@", code , error.localizedDescription)
            Logger.loading.debug(message)
            
            Logger.loading.debug(message)
            guard let networkError = knownErrorStates.first(where: { $0.osstatus == code }) else {
                return OptionsTaskState(OSStatus(code), error.localizedDescription, ErrorSeverity.fatal)
            }
            return networkError
    
        }
    }

