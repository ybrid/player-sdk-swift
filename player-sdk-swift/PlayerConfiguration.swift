//
// PlayerConfiguration.swift
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


#if !SWIFT_PACKAGE
extension Bundle {
    public static var module:Bundle { Bundle(identifier: AudioPlayer.bundleId)! }
}
#endif

public class PlayerConfiguration {
    
    var infoDict:[String:Any]?
    var envDict:[String:String]?
    var configsDict:[String:String]?
    
    init(bundleId:String) {
        infoDict = loadBundleInfo(bundleId: bundleId)
    }

    init(resource: String, withExtension ext: String) {
        configsDict = loadConfig(resource: resource, ext: ext)
    }

    
    public var bundleName:String? { get {
        #if SWIFT_PACKAGE
        let name = packageConfig("PRODUCT_NAME")
        #else
        let name = bundleInfo("CFBundleName")
        #endif
        guard let bundleName = name else {
            Logger.shared.error("no bundle name found")
            return nil
        }
        Logger.shared.debug("bundle name is \(bundleName)")
        return bundleName
    }}
    
    public var bundleVersion:String? { get {
        #if SWIFT_PACKAGE
        let version = packageConfig("MARKETING_VERSION")
        #else
        let version = bundleInfo("CFBundleShortVersionString")
        #endif
        guard let bundleVersion = version else {
            Logger.shared.error("no bundle version found")
            return nil
        }
        Logger.shared.debug("bundle version is \(bundleVersion)")
        return bundleVersion
    }}
 
    public var bundleBuildNumber:String? { get {
        #if SWIFT_PACKAGE
        let build = packageConfig("CURRENT_PROJECT_VERSION")
        #else
        let build = bundleInfo("CFBundleVersion")
        #endif
        guard let buildNumber = build else {
            Logger.shared.error("no bundle build number found")
            return nil
        }
        Logger.shared.debug("bundle build number is \(buildNumber)")
        return buildNumber
    }}
    
    // MARK: private helpers
    
    private func bundleInfo(_ dict:String) -> String? {
        return infoDict?[dict] as? String ?? nil
    }
    private func packageConfig(_ entry:String) -> String? {
        return configsDict?[entry] ?? nil
    }
    
    private func parseConfig(fileContent:String) -> [String:String] {
        var properties:[String:String] = [:]
        let dataArray = fileContent.components(separatedBy: "\n")
        for line in dataArray {
            if line.starts(with: "#") || line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            let components = line.split(separator: "=", maxSplits: 2).map(String.init)
            guard components.count == 2 else {
                Logger.shared.error("ignoring \(line)")
                continue
            }
            let key=components[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value=components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            properties[key] = value
        }
        return properties
    }
    
    private func loadBundleInfo(bundleId:String)  -> [String:Any]? {
        guard let info = Bundle.module.infoDictionary else {
            Logger.shared.error("no bundle info for \(bundleId) found")
            return nil
        }
        Logger.shared.info("bundle \(bundleId) info is \(info)")
        return info
    }
    
    private func loadConfig(resource: String, ext: String) -> [String:String]? {
        let configRessource = Bundle.module.url(forResource: resource, withExtension: ext)
        guard let configPath = configRessource?.path else {
            Logger.shared.error("no configs from \(resource).\(ext) found")
            return nil
        }
    
        do {
            let pckgConfig = try String(contentsOfFile: configPath, encoding: String.Encoding.utf8)
            let configs = parseConfig(fileContent: pckgConfig)
            Logger.shared.info("configs from \(configPath) \(configs)")
            return configs
        } catch {
            Logger.shared.error("cannot parse configs from \(configPath), cause: \(error.localizedDescription)")
            return nil
        }
    }

}
