//
//  MetadataExtractorTests.swift
//  app-example-iosTests
//
//  Created by Florian Nowotny on 10.09.20.
//  Copyright © 2020 Florian Nowotny. All rights reserved.
//

import XCTest
@testable import YbridPlayerSDK

class MetadataExtractorTests: XCTestCase {
 
    class TestMetadataListener : MetadataListener {
        func audiodataReady(_ data: Data) {
        }
        
        var titles:[String] = []
        func metadataReady(_ metadata: AbstractMetadata) {
            if let title = metadata.displayTitle {
                titles.append(title)
            }
        }
    }
    var consumer = TestMetadataListener()
    override func setUpWithError() throws {  }
    
    override func tearDownWithError() throws {
        consumer.titles.removeAll()
    }
     
    func testInit() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 100, listener: consumer)
        XCTAssert( extractor.intervalBytes == 100 )
    }
    
    func testEmptyData() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 0, listener: consumer)
        XCTAssert( extractor.intervalBytes == 0 )
        
        let input:Data = Data()
        let result = extractor.handle(payload: input)
        XCTAssert( result.count == 0 )
    }
    
    func testEmptyMetadataOnly() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 0, listener: consumer)
        XCTAssert( extractor.intervalBytes == 0 )
        
        var input:Data = Data()
        let content: [UInt8] = [0,0,0]
        input.append(contentsOf: content)
        let result = extractor.handle(payload: input)
        XCTAssert( result.count == 0 )
    }
    
    fileprivate func createMetadataBlock(with:String) -> Data {
        var output:Data = Data()
        let mdBytes:[UInt8] = Array(with.utf8)
        let size = (mdBytes.count-1) >> 4 + 1
        output.append(contentsOf: [UInt8(size)])
        let mdArray = Array(with.utf8)
        output.append(contentsOf: Array(with.utf8))
        output.append([0], count: size * 16 - mdArray.count)
        return output
    }

    func testSingleMetadataOnly() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 0, listener: consumer)
        XCTAssert( extractor.intervalBytes == 0 )
        let input = createMetadataBlock(with: "StreamTitle=hallo")
        let result = extractor.handle(payload: input)
        XCTAssertEqual(0, result.count)
        XCTAssertEqual( "hallo", consumer.titles[0] )
    }
    
    func testSingle16BytesMetadataOnly() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 0, listener: consumer)
        XCTAssert( extractor.intervalBytes == 0 )
        let input = createMetadataBlock(with: "StreamTitle=hell")
        XCTAssertEqual( 17, input.count )
        
        let result = extractor.handle(payload: input)
        XCTAssert( result.count == 0 )
        XCTAssertEqual( "hell",  consumer.titles[0] )
    }
    
    func testSomeMetadataOnly() throws {
        var input:Data = Data()
        input.append(createMetadataBlock(with: "StreamTitle=do"))
        input.append(createMetadataBlock(with: "StreamTitle=re"))
        input.append(createMetadataBlock(with: "StreamTitle=mi,fa,so,la"))

        let extractor = MetadataExtractor(bytesBetweenMetadata: 0, listener: consumer)
        let result = extractor.handle(payload: input)
        XCTAssert( result.count == 0 )
        XCTAssertEqual( 3, consumer.titles.count )
        XCTAssertEqual( "re", consumer.titles[1] )
        XCTAssertEqual( "mi,fa,so,la", consumer.titles[2] )
    }
}
