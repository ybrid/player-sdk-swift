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

// Playing audio always operates in the context of the operating system.
// This class deals with the following topics.
//
// audio session:
// The process interacts with other processes or apps playing audio. We interact with AVAudioSession from the os.
//
// network monitoring:
// Streaming audio requires a network. We monitor the state of the network connection.
//
// memory limit:
// Detecting wheather the process' memory usage exceeds a defined memory limit

import AVFoundation
import Network
import SystemConfiguration

// NetworkListeners are informed about loss and reconnects of the network
protocol NetworkListener : class {
    func notifyNetworkChanged(_ connected:Bool)
}
// MemoryListeners are informed about memory warnings
protocol MemoryListener : class {
    func notifyExceedsMemoryLimit()
}
public class PlayerContext {
    
    // the priority of all dispatch queues used by this player
    static let processingPriority:DispatchQoS = DispatchQoS.utility
    
    // MARK: audio session
    
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
    
    // MARK: network monitoring
    
    static let networkMonitor = NetworkMonitor()
    static func register(listener: NetworkListener) {
        let id = UInt(bitPattern: ObjectIdentifier(listener))
        networkMonitor.listeners.put(id: id, value: listener)
        if Logger.verbose { Logger.loading.debug("\(networkMonitor.listeners.count) network listeners") }
    }
    static func unregister(listener: NetworkListener) {
        let id = UInt(bitPattern: ObjectIdentifier(listener))
        networkMonitor.listeners.remove(id: id)
        if Logger.verbose { Logger.loading.debug("\(networkMonitor.listeners.count) network listeners") }
    }

    class NetworkMonitor {
        var listeners = ThreadsafeDictionary<UInt,NetworkListener>(queueLabel: "io.ybrid.context.networkListening")
        var connected:Bool = false {
            didSet {
                if oldValue != connected {
                    Logger.loading.notice("network \(connected ? "connected" : "disconnected") -> notifying \(listeners.count) listeners")
                    listeners.forEachValue { (listener) in
                        listener.notifyNetworkChanged(connected) }
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
                if Logger.verbose { Logger.loading.debug("network \(path.debugDescription)") }
                let isConnected = (path.status == .satisfied)
                self.updateConnected(isConnected)
            }
            monitor.start(queue: DispatchQueue(label: "io.ybrid.networkMonitor"))
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
    
    // MARK: memory limit
    
    public static var memoryLimitMB:Float = 128.0
    static var sharedMemoryMonitor:MemoryMonitor = MemoryMonitor()
    public static func handleMemoryLimit() -> Bool {
        return sharedMemoryMonitor.handleLimit(PlayerContext.memoryLimitMB)
    }
    
    static func registerMemoryListener(listener: MemoryListener) {
        let id = UInt(bitPattern: ObjectIdentifier(listener))
        sharedMemoryMonitor.listeners.put(id: id, value: listener)
        Logger.loading.debug("\(sharedMemoryMonitor.listeners.count) memory listeners")
    }
    static func unregisterMemoryListener(listener: MemoryListener) {
        let id = UInt(bitPattern: ObjectIdentifier(listener))
        sharedMemoryMonitor.listeners.remove(id: id)
        Logger.loading.debug("\(sharedMemoryMonitor.listeners.count) memory listeners")
    }
    
    class MemoryMonitor {
        var listeners = ThreadsafeDictionary<UInt,MemoryListener>(queueLabel: "io.ybrid.context.memoryListening")
        
        init(){}
        func handleLimit(_ maxMB:Float ) -> Bool {
            guard isMemory(exceedingMB:maxMB) else {
                return false
            }
            Logger.shared.error("nofiying \(listeners.count) memory listeners")
            listeners.forEachValue{ (listener) in
                listener.notifyExceedsMemoryLimit()
            }
            return true
        }
        
        func isMemory(exceedingMB limitMB:Float) -> Bool {
            if let usedMB = memoryFootprint()?.used {
                Logger.shared.error(String(format: "using %.1f MB exceeds memory limit of %.1f MB", usedMB, limitMB))
                return usedMB > limitMB
            }
            return false
        }
        
        func memoryFootprint() -> (used:Float,resident:Float, peak:Float)? {
            // The `TASK_VM_INFO_COUNT` and `TASK_VM_INFO_REV1_COUNT` macros are too
            // complex for the Swift C importer, so we have to define them ourselves.
            let TASK_VM_INFO_COUNT = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
            let TASK_VM_INFO_REV1_COUNT = mach_msg_type_number_t(MemoryLayout.offset(of: \task_vm_info_data_t.min_address)! / MemoryLayout<integer_t>.size)
            var info = task_vm_info_data_t()
            var count = TASK_VM_INFO_COUNT
            let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
                infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                    task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
                }
            }
            guard kr == KERN_SUCCESS, count >= TASK_VM_INFO_REV1_COUNT
            else { return nil }
            
            let footprint = Float(info.phys_footprint) / 1024 / 1024
            let resident =  Float(info.resident_size) / 1024 / 1024
            let residentPeak =  Float(info.resident_size_peak) / 1024 / 1024
            
            return (footprint,resident, residentPeak)
        }
    }
}

class ThreadsafeDictionary<K:Hashable,V> {
    private let queue:DispatchQueue
    private var entries:[K:V] = [:]
    init(queueLabel:String) {
        self.queue = DispatchQueue(label: queueLabel, qos: PlayerContext.processingPriority)
    }
    var count: Int { get { return queue.sync {() -> Int in return entries.count }}}
    func forEachValue( act: (V) -> () ) {
        queue.sync {
            for entry in entries {
                act(entry.1)
            }}
    }
    func put(id:K, value: V) {
            queue.async {
                self.entries[id] = value
            }
        }
//    func get(id:K) -> V? {
//        return queue.sync { ()-> V? in
//            return entries[id]
//        }
//    }
    func remove(id:K) {
        queue.async {
            self.entries[id] = nil
        }
    }
    func pop(id:K) -> V? {
        return queue.sync { ()-> V? in
            let value = entries[id]
            entries[id] = nil
            return value
        }
    }
    
    func removeAll()  {
        queue.async {
            self.entries.removeAll()
        }
    }
}
