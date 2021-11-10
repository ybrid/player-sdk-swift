//
// Bouquet.swift
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


class Bouquet {
    
    let services:[Service]
    var defaultService:Service?
    let activeService:Service
    
    init(bouquet: YbridBouquet) throws {
        self.services = bouquet.availableServices.map{
            var service = Service(identifier: $0.id)
            if let name = $0.displayName?.value { service.displayName = name }
            if let icon = $0.iconURL?.value { service.iconUri = icon }
            return service
        }
        if let mainServiceIndex = self.services.firstIndex(where: { (service) in return service.identifier == bouquet.primaryServiceId }) {
            self.defaultService = services[mainServiceIndex]
        } else {
            let error = SessionError(.invalidBouquet, "missing primary service id")
            Logger.session.notice(error.localizedDescription)
       }
        let activeServiceIndex = self.services.firstIndex { (service) in return service.identifier == bouquet.activeServiceId }
        guard let activeIndex = activeServiceIndex else {
            throw SessionError(.invalidBouquet, "missing active service id")
        }
        self.activeService = services[activeIndex]
    }
}


extension String {
    var value:String? { get {
        let value = self.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !value.isEmpty {
            return value
        }
        return nil
    }}
}
