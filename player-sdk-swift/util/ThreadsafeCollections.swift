//
// ThreadsafeCollections.swift
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

class ThreadsafeDequeue<T> {
    private let queue = DispatchQueue(label: "io.ybrid.decoding.source", qos: PlayerContext.processingPriority)
    
    private var packages = [T]()
    
    var count:Int { queue.sync { return packages.count } }
    
    func put(_ package: T) {
        queue.async { self.packages.append(package) }
    }
    
    func take() -> T? {
        queue.sync {
            guard packages.count > 0 else { return nil }
            return packages.removeFirst()
        }
    }
    
    func clear() { queue.async { self.packages.removeAll() } }
}


class ThreadsafeSet<T:Hashable> {
    private var entries = Set<T>()
    private let queue:DispatchQueue
    init(_ queueLabel:String) {
        queue = DispatchQueue(label: queueLabel, qos: .background)
    }
    var count:Int {
        return queue.sync {
            return self.entries.count
        }
    }
    func insert(_ entry:T) {
        queue.async {
            self.entries.insert(entry)
        }
    }
    func popAll(act: @escaping (T) -> () ) {
        queue.async {
            while let entry = self.entries.popFirst() {
                act(entry)
            }
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

