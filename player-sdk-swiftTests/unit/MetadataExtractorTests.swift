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
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
     
    func testInit() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 100)
        XCTAssert( extractor.intervalBytes == 100 )
    }
    
    func testEmptyData() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 0)
        XCTAssert( extractor.intervalBytes == 0 )
        
        let input:Data = Data()
        let result = extractor.handle(payload: input, metadataCallback: nil)
        XCTAssert( result.count == 0 )
    }
    
    func testEmptyMetadataOnly() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 0)
        XCTAssert( extractor.intervalBytes == 0 )
        
        var input:Data = Data()
        let content: [UInt8] = [0,0,0]
        input.append(contentsOf: content)
        let result = extractor.handle(payload: input, metadataCallback: nil)
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
        let extractor = MetadataExtractor(bytesBetweenMetadata: 0)
        XCTAssert( extractor.intervalBytes == 0 )
        let input = createMetadataBlock(with: "StreamTitle=hallo")
        var extractedTitle:String = ""
        let result = extractor.handle(payload: input, metadataCallback: { (md:[String:String]) in
            if let mdExtracted = md.first {
                extractedTitle = mdExtracted.1
            }
        })
        XCTAssertEqual(0, result.count)
        XCTAssertEqual( "hallo", extractedTitle )
    }
    
    func testSingle16BytesMetadataOnly() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 0)
        XCTAssert( extractor.intervalBytes == 0 )
        let input = createMetadataBlock(with: "StreamTitle=hell")
        XCTAssertEqual( 17, input.count )
        var extractedTitle:String = ""
        let result = extractor.handle(payload: input, metadataCallback: { (md:[String:String]) in
            if let mdExtracted = md.first {
                extractedTitle = mdExtracted.1
            }
        })
        XCTAssert( result.count == 0 )
        XCTAssertEqual( "hell", extractedTitle )
    }
    
    func testSomeMetadataOnly() throws {
        var input:Data = Data()
        input.append(createMetadataBlock(with: "StreamTitle=do"))
        input.append(createMetadataBlock(with: "StreamTitle=re"))
        input.append(createMetadataBlock(with: "StreamTitle=mi,fa,so,la"))

        let extractor = MetadataExtractor(bytesBetweenMetadata: 0)
        var extractedTitles:[String] = []
        let result = extractor.handle(payload: input, metadataCallback: { (md:[String:String]) in
            if let mdExtracted = md.first {
                extractedTitles.append(mdExtracted.1)
            }
        })
        XCTAssert( result.count == 0 )
        XCTAssertEqual( 3, extractedTitles.count )
        XCTAssertEqual( "re", extractedTitles[1] )
        XCTAssertEqual( "mi,fa,so,la", extractedTitles[2] )
    }
}
