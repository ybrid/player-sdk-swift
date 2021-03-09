//
// LoadingErrors.swift
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

class LoadingErrors {
    
    private class CodeMap {
        let code:Int
        let message:String?
        let type:ProblemType
        var whileStallingType:ProblemType?
        init(_ code:Int, _ message:String?, _ type:ProblemType, _ whileStalling:ProblemType? = nil) {
            self.code = code
            self.message = message
            self.type = type
            self.whileStallingType = whileStalling
        }
    }
    
    static private var networkCodeMaps: [CodeMap] = [
        CodeMap(-1001, "timed out loading data", .stalled),
        CodeMap(-1002, "unsupported URL", .fatal),
        CodeMap(-1003, "host not found", .fatal, .stalled),
        CodeMap(-1005, "connection lost", .stalled),
        CodeMap(-1009, "offline?", .fatal, .stalled),
        CodeMap(-1022, "not https", .fatal),
        CodeMap(-1200, "cannot connect over SSL",.fatal),
        CodeMap(-997, nil, .notice)
    ]
    
    static func mapCFNetworkErrors(_ error: Error, stalling: Bool) -> (type:ProblemType,msg: String)? {
        let nserr = error as NSObject
        let code = nserr.value(forKey: "code") as! NSNumber.IntegerLiteralType
        if code == -999 {
            return nil /// stopped regularily
        }
        
        let pattern = "task completed with code=%d %@"
        Logger.loading.info(String(format: pattern, code , error.localizedDescription))
        
        if let mapping = networkCodeMaps.first(where: { $0.code == code }) {
            if stalling && mapping.whileStallingType != nil {
                return (mapping.whileStallingType!, "still stalling")
            }
            return (mapping.type, mapping.message ?? error.localizedDescription)
        }
        return( .unknown, error.localizedDescription)
    }
}

