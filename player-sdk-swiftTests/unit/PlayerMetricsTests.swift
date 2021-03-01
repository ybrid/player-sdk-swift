//
//  PlayerMetricsTests.swift
//  app-example-iosTests
//
//  Created by Florian Nowotny on 15.09.20.
//  Copyright © 2020 Florian Nowotny. All rights reserved.
//

import XCTest
@testable import YbridPlayerSDK

class PlayerMetricsTests: XCTestCase {
    
    var metrics:PlaybackEngine.Metrics?
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        metrics = PlaybackEngine.Metrics()
    }
    
    override func tearDownWithError() throws {
        try super.tearDownWithError()
        metrics?.buffers = []
    }
    
     
    func testBufferSEmpty() throws {
        let result = metrics?.averagedBufferS(nil)
        XCTAssertNil(result)
    }
    
    func testBufferSEmptyFirst() throws {
        let result = metrics?.averagedBufferS(2.0)
        XCTAssertEqual(2.0, result)
    }
    
    func testBufferSEmptyTwoSame() throws {
        _ = metrics?.averagedBufferS(2.0)
        let result = metrics?.averagedBufferS(2.0)
        XCTAssertEqual(2.0, result)
    }
    
    func testBufferSEmptyTwoAvrg() throws {
        _ = metrics?.averagedBufferS(2.0)
        let result = metrics?.averagedBufferS(3.0)
        XCTAssertEqual(2.5, result)
    }
    
    
    func testBufferSDelayed1STwoAvrg() throws {
        metrics?.averageS = 1.0
        
        _ = metrics?.averagedBufferS(2.0)
        Thread.sleep(forTimeInterval: 0.9)
        guard let result = metrics?.averagedBufferS(3.0) else {
            XCTFail(); return }
        XCTAssertEqual(2.5, result)
    }
    
    func testBufferSDelayed2STwoAvrg() throws {
        metrics?.averageS = 1.0
        
        _ = metrics?.averagedBufferS(2.0)
        Thread.sleep(forTimeInterval: 1.1)
        guard let result = metrics?.averagedBufferS(3.0) else {
            XCTFail(); return }
        XCTAssertEqual(3.0, result)
    }
    
    func testBufferSDelayedAvrg() throws {
        metrics?.averageS = 0.49
        var val = 0.0
        repeat {
            _ = metrics?.averagedBufferS(val)
            Thread.sleep(forTimeInterval: 0.1)
            val += 0.1
        } while val < 0.999
        guard let result = metrics?.averagedBufferS(val) else {
            XCTFail(); return }
        XCTAssertEqual(0.8, result, accuracy: 0.001)
    }
    
}
