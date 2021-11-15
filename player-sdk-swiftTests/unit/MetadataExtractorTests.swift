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
        var titles:[String] = []
        func metadataReady(_ metadata: AbstractMetadata) {
            titles.append(metadata.displayTitle)
        }
        
        var datas:[Data] = []
        func audiodataReady(_ data: Data) {
            datas.append(data)
        }
    }
    var consumer = TestMetadataListener()
    override func setUpWithError() throws {  }
    
    override func tearDownWithError() throws {
        consumer.titles.removeAll()
    }
     
    func testInit() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 100)
        XCTAssert( extractor.intervalBytes == 100 )
    }
    
    func testEmptyData() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 0)
        XCTAssert( extractor.intervalBytes == 0 )
        
        let input:Data = Data()
        extractor.dispatch(payload: input, metadataReady: consumer.metadataReady, audiodataReady: consumer.audiodataReady)
        
        XCTAssertEqual(consumer.datas.count, 0)
        XCTAssertEqual(consumer.titles.count, 0)
    }
    
    func testEmptyMetadataOnly() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 0)
        XCTAssert( extractor.intervalBytes == 0 )
        
        var input:Data = Data()
        let content: [UInt8] = [0,0,0]
        input.append(contentsOf: content)
        extractor.dispatch(payload: input, metadataReady: consumer.metadataReady, audiodataReady: consumer.audiodataReady)
        
        XCTAssertEqual(consumer.datas.count, 0)
        XCTAssertEqual(consumer.titles.count, 0)
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
        extractor.dispatch(payload: input, metadataReady: consumer.metadataReady, audiodataReady: consumer.audiodataReady)
        
        XCTAssertEqual(consumer.datas.count, 0)
        XCTAssertEqual(consumer.titles.count, 1)
        
        XCTAssertEqual( "hallo", consumer.titles[0] )
    }
    
    func testSingle16BytesMetadataOnly() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 0)
        XCTAssert( extractor.intervalBytes == 0 )
        let input = createMetadataBlock(with: "StreamTitle=hell")
        XCTAssertEqual( 17, input.count )
        
        extractor.dispatch(payload: input, metadataReady: consumer.metadataReady, audiodataReady: consumer.audiodataReady)
        
        XCTAssertEqual(consumer.datas.count, 0)
        XCTAssertEqual(consumer.titles.count, 1)
        
        XCTAssertEqual( "hell", consumer.titles[0] )
    }
    
    func testSomeMetadataOnly() throws {
        var input:Data = Data()
        input.append(createMetadataBlock(with: "StreamTitle=do"))
        input.append(createMetadataBlock(with: "StreamTitle=re"))
        input.append(createMetadataBlock(with: "StreamTitle=mi,fa,so,la"))

        let extractor = MetadataExtractor(bytesBetweenMetadata: 0)
        extractor.dispatch(payload: input, metadataReady: consumer.metadataReady, audiodataReady: consumer.audiodataReady)
        
        XCTAssertEqual(consumer.datas.count, 0)
        XCTAssertEqual( consumer.titles.count, 3 )
        XCTAssertEqual( "re", consumer.titles[1] )
        XCTAssertEqual( "mi,fa,so,la", consumer.titles[2] )
    }
    
    
    
    func testAudiodataOnly() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 5)
        
        var input:Data = Data()
        let content: [UInt8] = [1,1,1]
        input.append(contentsOf: content)
        extractor.dispatch(payload: input, metadataReady: consumer.metadataReady, audiodataReady: consumer.audiodataReady)
        XCTAssertEqual(consumer.datas.count, 0)
        extractor.flush(consumer.audiodataReady)
        
        XCTAssertEqual(consumer.datas.count, 1)
        XCTAssertEqual(consumer.titles.count, 0)
        
        XCTAssertEqual(consumer.datas.map { $0.count }.reduce(0, +), 3)
    }

    func testAudio0MetaAudio() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 5)
        
        var input:Data = Data()
        let content: [UInt8] = [1,1,1,1,1,0,1,1,1]
        input.append(contentsOf: content)
        extractor.dispatch(payload: input, metadataReady: consumer.metadataReady, audiodataReady: consumer.audiodataReady)
        XCTAssertEqual(consumer.datas.count, 1)
        extractor.flush(consumer.audiodataReady)
        
        XCTAssertEqual(consumer.datas.count, 2)
        XCTAssertEqual(consumer.titles.count, 0)
        
        XCTAssertEqual(consumer.datas.map { $0.count }.reduce(0, +), 8)
    }

    func testAudioMeta() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 5)
        
        var input:Data = Data()
        let content: [UInt8] = [1,1,1,1,1]
        input.append(contentsOf: content)
        input.append(createMetadataBlock(with: "bla"))
        XCTAssertEqual(input.count, 5+17)
        
        extractor.dispatch(payload: input, metadataReady: consumer.metadataReady, audiodataReady: consumer.audiodataReady)
        XCTAssertEqual(consumer.datas.count, 1)
        extractor.flush(consumer.audiodataReady)
        
        XCTAssertEqual(consumer.datas.count, 2)
        XCTAssertEqual(consumer.titles.count, 1)
        guard let title = consumer.titles.first else { XCTFail(); return }
        XCTAssertEqual(title, "")
        
        XCTAssertEqual(consumer.datas.map { $0.count }.reduce(0, +), 5)
    }
    
    func testAudioMetaAudio() throws {
        let extractor = MetadataExtractor(bytesBetweenMetadata: 5)
        
        var input:Data = Data()
        let content: [UInt8] = [1,1,1,1,1]
        input.append(contentsOf: content)
        input.append(createMetadataBlock(with: "StreamTitle=bla"))
        input.append(contentsOf: content)
        XCTAssertEqual(input.count, 2*5+17)
        
        extractor.dispatch(payload: input, metadataReady: consumer.metadataReady, audiodataReady: consumer.audiodataReady)
        extractor.flush(consumer.audiodataReady)
        
        XCTAssertEqual(consumer.datas.count, 2)
        XCTAssertEqual(consumer.titles.count, 1)
        guard let title = consumer.titles.first else { XCTFail(); return }
        XCTAssertEqual(title, "bla")
        
        
        XCTAssertEqual(consumer.datas.map { $0.count }.reduce(0, +), 10)
    }


    
}
