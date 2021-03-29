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
//
// It interacts with other apps playing audio. We interact with AVAudioSession from the os.
// Streaming audio requires a network. We monitor the state of network connection.

import AVFoundation
import Network
import SystemConfiguration


protocol NetworkListener : class {
    func notifyNetworkChanged(_ connected:Bool)
}
protocol MemoryListener : class {
    func notifyExceedsMemoryLimit()
}
public class PlayerContext {

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
        if networkMonitor.listeners[id] == nil {
            weak var weakListener = listener
            networkMonitor.listeners[id] = weakListener
        }
        if Logger.verbose { Logger.loading.debug("\(networkMonitor.listeners.count) network listeners") }
    }
    static func unregister(listener: NetworkListener) {
        let id = UInt(bitPattern: ObjectIdentifier(listener))
        // sometimes EXC_BAD_ACCESS here -> TODO thread safe access to dictionary
        networkMonitor.listeners[id] = nil
        if Logger.verbose { Logger.loading.debug("\(networkMonitor.listeners.count) network listeners") }
    }

    class NetworkMonitor {
        var listeners:[UInt:NetworkListener] = [:]
        var connected:Bool = false {
            didSet {
                if oldValue != connected {
                    Logger.loading.notice("network \(connected ? "connected" : "disconnected") -> notifying \(listeners.count) listeners")
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
    static private var sharedMemoryMonitor:MemoryMonitor = MemoryMonitor()
    public static func handleMemoryLimit() -> Bool {
        return sharedMemoryMonitor.handleLimit(PlayerContext.memoryLimitMB)
    }
    
    static func registerMemoryListener(listener: MemoryListener) {
        let id = UInt(bitPattern: ObjectIdentifier(listener))
        if sharedMemoryMonitor.listeners[id] == nil {
            weak var weakListener = listener
            sharedMemoryMonitor.listeners[id] = weakListener
        }
        Logger.loading.debug("\(sharedMemoryMonitor.listeners.count) memory listeners")
    }
    static func unregisterMemoryListener(listener: MemoryListener) {
        let id = UInt(bitPattern: ObjectIdentifier(listener))
        // sometimes EXC_BAD_ACCESS here -> TODO thread safe access to dictionary
        sharedMemoryMonitor.listeners[id] = nil
        Logger.loading.debug("\(sharedMemoryMonitor.listeners.count) memory listeners")
    }

    class MemoryMonitor {
        var listeners:[UInt:MemoryListener] = [:]
        init(){}
        func handleLimit(_ maxMB:Float ) -> Bool {
            guard isMemory(exceedingMB:maxMB) else {
                return false
            }
            Logger.shared.error("nofiying \(listeners.count) memory listeners")
            for listener in listeners {
                listener.1.notifyExceedsMemoryLimit()
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

//func vw_page_size() -> (kern_return_t, vm_size_t) {
//    var pageSize: vm_size_t = 0
//    let result = withUnsafeMutablePointer(to: &pageSize) { (size) -> kern_return_t in
//        host_page_size(mach_host_self(), size)
//    }
//
//    return (result, pageSize)
//}
//
//func vm_stat() -> (kern_return_t, vm_statistics) {
//    var vmstat = vm_statistics()
//    var count = UInt32(MemoryLayout<vm_statistics>.size / MemoryLayout<integer_t>.size)
//    let result = withUnsafeMutablePointer(&vmstat, &count) { (stat, count) -> kern_return_t in
//        host_statistics(mach_host_self(), HOST_VM_INFO, host_info_t(stat), count)
//    }
//    let result = withUnsafeMutablePointer(&vmstat, &count) { (stat, count) -> kern_return_t in
//        host_statistics(mach_host_self(), HOST_VM_INFO, host_info_t(stat), count)
//    }
//
//    return (result, vmstat)
//}
//
//func vmMem() -> (totalGB:UInt, freeMB:UInt) {
//    let (result1, pageSize) = vw_page_size()
//    let (result2, vmstat) = vm_stat()
//
//    guard result1 == KERN_SUCCESS else {
//        fatalError("Cannot get VM page size")
//    }
//    guard result2 == KERN_SUCCESS else {
//        fatalError("Cannot get VM stats")
//    }
//
//    let total = (UInt(vmstat.free_count + vmstat.active_count + vmstat.inactive_count + vmstat.speculative_count + vmstat.wire_count) * pageSize) >> 30
//    let free = (UInt(vmstat.free_count) * pageSize) >> 20
//
//    print("total: \(total)GB")
//    print("free : \(free)MB")
//    return (total, free)
//}
//
func showMemory() {
    let megabytes = getMemoryUsedAndDeviceTotalInMegabytes()
    let ratio = megabytes.used / megabytes.maxUse
    Logger.shared.notice(String(format: "using %.0f MB of %.0f MB memory.", megabytes.used, megabytes.maxUse))
    if ratio > 0.45 {
        Logger.shared.notice("will cut buffer and stop loading data")
    }


    if let memory = memoryFootprint() {
        Logger.shared.notice(String(format: "used MB %.0f MB, resident %.0f MB, resident_peak %.0f MB", memory.used, memory.resident, memory.peak))
    }

    if let available = availableMemory() {
        Logger.shared.notice(String(format: "used MB %.0f MB, free %.0f MB", available.used, available.free))
}
}


func availableMemory() -> (used:Float, free:Float)? {
    var pagesize: vm_size_t = 0

    let host_port: mach_port_t = mach_host_self()
    var host_size: mach_msg_type_number_t = mach_msg_type_number_t(MemoryLayout<vm_statistics_data_t>.stride / MemoryLayout<integer_t>.stride)
    host_page_size(host_port, &pagesize)

    var vm_stat: vm_statistics = vm_statistics_data_t()
    withUnsafeMutablePointer(to: &vm_stat) { (vmStatPointer) -> Void in
        vmStatPointer.withMemoryRebound(to: integer_t.self, capacity: Int(host_size)) {
            if (host_statistics(host_port, HOST_VM_INFO, $0, &host_size) != KERN_SUCCESS) {
                NSLog("Error: Failed to fetch vm statistics")
            }
        }
    }

    /* Stats in bytes */
    let mem_used: Int64 = Int64(vm_stat.active_count +
            vm_stat.inactive_count +
            vm_stat.wire_count) * Int64(pagesize)
    let mem_free: Int64 = Int64(vm_stat.free_count) * Int64(pagesize)
    return (Float(mem_used)/1024/1024, Float(mem_free)/1024/1024)
}


//    https://gist.github.com/pejalo/671dd2f67e3877b18c38c749742350ca
func getMemoryUsedAndDeviceTotalInMegabytes() -> (used:Float, maxUse:Float, total:Float) {
        
    // https://stackoverflow.com/questions/5887248/ios-app-maximum-memory-budget/19692719#19692719
    // https://stackoverflow.com/questions/27556807/swift-pointer-problems-with-mach-task-basic-info/27559770#27559770
    
    var used_megabytes: Float = 0
    var max_megabytes: Float = 0
    
    let total_bytes = Float(ProcessInfo.processInfo.physicalMemory)
    let total_megabytes = total_bytes / 1024.0 / 1024.0

    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(
                mach_task_self_,
                task_flavor_t(MACH_TASK_BASIC_INFO),
                $0,
                &count
            )
        }
    }
    
    if kerr == KERN_SUCCESS {
        let used_bytes: Float = Float(info.resident_size)
        used_megabytes = used_bytes / 1024.0 / 1024.0
        
        
        let max_use_bytes: Float = Float(info.resident_size_max)
        max_megabytes = max_use_bytes / 1024.0 / 1024.0
    }
    
    return (used_megabytes, max_megabytes, total_megabytes)
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


