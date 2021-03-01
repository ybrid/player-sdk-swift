//
// PlayerContext.swift
// player-sdk-swift
//
// Copyright (c) 2020 nacamar GmbH - Ybrid®, a Hybrid Dynamic Live Audio Technology
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


import AVFoundation
import Network
import SystemConfiguration


protocol NetworkListener : class {
    func notifyNetworkChanged(_ connected:Bool)
}
 
class PlayerContext {

    static let processingPriority:DispatchQoS = DispatchQoS.utility
    
#if os(iOS)
    static func setupAudioSession() {
        let avs = AVAudioSession.sharedInstance()
        do {
            Logger.playing.debug("available catergories \(avs.availableCategories)")
            Logger.playing.debug("available modes \(avs.availableModes)")
            
            // swift 4
            try avs.setCategory(AVAudioSessionCategoryPlayback, with: [])
            try avs.setMode(AVAudioSessionModeDefault)

            Logger.playing.debug("current category \(avs.category)")
            Logger.playing.debug("current mode \(avs.mode)")
            Logger.playing.debug("outputs \(avs.outputDataSources)")
            Logger.playing.debug("prefered buffer duration \(avs.preferredIOBufferDuration)")
            Logger.playing.debug("prefered sample rate \(avs.preferredSampleRate)")
            Logger.playing.debug("current output \(avs.currentRoute.outputs)")
            Logger.playing.debug("latencies input \(avs.inputLatency*1000) ms , output \(avs.outputLatency*1000) ms")
            
        } catch {
            Logger.playing.error("Failed to setup AVAudioSession, cause \(error.localizedDescription)")
        }
        
        do {
            // swift 4
            try avs.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            Logger.playing.error("Failed to activate AVAudioSession, cause \(error.localizedDescription)")
        }
    }
#else
    static func setupAudioSession() {}
#endif
        
#if os(iOS)
    static func deactivate() {
        do {
            let avs = AVAudioSession.sharedInstance()
            try avs.setActive(false)
        } catch {
            Logger.playing.error("Failed to deactivate AVAudioSession, cause \(error.localizedDescription)")
        }
    }
#else
    static func deactivate() {}
#endif

    static let networkMonitor = NetworkMonitor()
    
    static func register(listener: NetworkListener) {
        let id = UInt(bitPattern: ObjectIdentifier(listener))
        networkMonitor.listeners[id] = listener
        Logger.shared.debug("\(networkMonitor.listeners.count) network listeners")
    }
    static func unregister(listener: NetworkListener) {
        let id = UInt(bitPattern: ObjectIdentifier(listener))
        networkMonitor.listeners[id] = nil
        Logger.shared.debug("\(networkMonitor.listeners.count) network listeners")
    }

    class NetworkMonitor {
        var listeners:[UInt:NetworkListener] = [:]
        var connected:Bool = false {
            didSet {
                if oldValue != connected {
                    Logger.shared.notice("network \(connected ? "connected" : "disconnected") -> \(listeners.count) listeners")
                    for listener in listeners {
                        listener.1.notifyNetworkChanged(connected)
                    }
                }
            }
        }
        var triggered:Bool = false
        init() {
            if #available(iOS 12, macOS 10.14, *) {
                createAndStartNWMonitor()
            } else {
                registerObserver("com.apple.system.config.network_change")
            }
            self.connected = isConnectedToNetwork()
        }
        
        deinit {
            if #available(iOS 12, *) {
            } else {
                removeObserver()
            }
        }
        
        @available(iOS 12, macOS 10.14, *)
        func createAndStartNWMonitor() {
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                Logger.shared.debug("network \(path.debugDescription)")
                let isConnected = (path.status == .satisfied)
                self.updateConnected(isConnected)
            }
            monitor.start(queue: DispatchQueue(label: "de.addradio.networkMonitor"))
        }
        
        func updateConnected(_ isConnected:Bool) {
            if connected != isConnected {
                connected = isConnected
                return
            }
            
            if self.connected == isConnected {
                if !triggered {
                    self.trigger()
                }
            }
        }
        
        private func trigger() {
            triggered = true
            DispatchQueue.global().async {
                usleep(200_000)
                self.connected = self.isConnectedToNetwork()
                self.triggered = false
            }
        }
        
        private func registerObserver(_ notificationName: String ) {
            let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
            CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer,
                                            { (nc, observer, name, _, _) -> Swift.Void in
                                                if let observer = observer {
                                                    let instance = Unmanaged<NetworkMonitor>.fromOpaque(observer).takeUnretainedValue()
                                                    let isConnected = instance.isConnectedToNetwork()
                                                    instance.updateConnected(isConnected)
                                                } },
                                            notificationName as CFString, nil, .deliverImmediately)
        }
        
        private func removeObserver() {
            let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
            CFNotificationCenterRemoveObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer, nil, nil)
        }
        
        func isConnectedToNetwork() -> Bool {
            var zeroAddress = sockaddr_in()
            zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
            zeroAddress.sin_family = sa_family_t(AF_INET)
            
            let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                    SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
                }
            }
            
            var flags = SCNetworkReachabilityFlags()
            if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
                return false
            }
            let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
            let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
            return (isReachable && !needsConnection)
        }
    }
    
}
