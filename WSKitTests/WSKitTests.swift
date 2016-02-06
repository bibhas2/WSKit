//
//  WSKitTests.swift
//  WSKitTests
//
//  Created by Bibhas Bhattacharya on 1/31/16.
//  Copyright © 2016 Bibhas Bhattacharya. All rights reserved.
//

import XCTest
@testable import WSKit

class WSKitTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testGET() {
        let feature = self.expectationWithDescription("Test")
        
        WS.url("http://httpbin.org/get")
            .get()
            .then { (res) -> Void in
                let body = res.body
                print(body)
                let range = body.rangeOfString("Accept-Encoding")
                XCTAssertNotEqual(range, nil)
                feature.fulfill()
            }.error {err in
                print(err)
                XCTFail("Got error")
                feature.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(10) { (err) -> Void in
            if (err != nil) {
                XCTFail("Got timeout")
            }
        }
    }
    
    func testGETJSON() {
        let feature = self.expectationWithDescription("Test")
        
        WS.url("http://httpbin.org/get")
            .get()
            .then { (res) -> Void in
                if let json = res.json {
                    var obj = json as! [String:AnyObject]
                    
                    XCTAssertEqual(obj["url"] as? String, Optional.Some("http://httpbin.org/get"))
                } else {
                    XCTFail("Got error trying to get JSON")
                }
                feature.fulfill()
            }.error {err in
                print(err)
                XCTFail("Got error")
                feature.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(10) { (err) -> Void in
            if (err != nil) {
                XCTFail("Got timeout")
            }
        }
    }
    
    func testGETBadJSON() {
        let feature = self.expectationWithDescription("Test")
        
        WS.url("http://example.com")
            .get()
            .then { (res) -> Void in
                if let _ = res.json {
                    XCTFail("JSON parsing should have failed")
                } else {
                    print("Got error trying to get JSON. This was expected.")
                }
                feature.fulfill()
            }.error {err in
                print(err)
                XCTFail("Got error")
                feature.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(10) { (err) -> Void in
            if (err != nil) {
                XCTFail("Got timeout")
            }
        }
    }
    
    func testResponseStatus() {
        let feature = self.expectationWithDescription("Test")
        
        //Response will have 404 status
        WS.url("http://httpbin.org/get/404")
            .get()
            .then { (res) -> Void in
                print(res.body)
                XCTFail("This request should fail.")
                feature.fulfill()
            }.error {err in
                //Error is expected
                print(err)
                feature.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(10) { (err) -> Void in
            if (err != nil) {
                XCTFail("Got timeout")
            }
        }
    }
    
    func testJSONPOST() {
        let feature = self.expectationWithDescription("Test")
        
        WS.url("http://httpbin.org/post")
            .withHeaders(["Content-Type":"application/json"])
            .post("{'hello':'mama'}")
            .then { (res) -> Void in
                let body = res.body
                print(body)
                let range = body.rangeOfString("{'hello':'mama'}")
                XCTAssertNotEqual(range, nil)
                feature.fulfill()
            }.error {err in
                print(err)
                XCTFail("Got error")
                feature.fulfill()
        }
        
        self.waitForExpectationsWithTimeout(10) { (err) -> Void in
            if (err != nil) {
                XCTFail("Got timeout")
            }
        }
    }
    
    func testMapPOST() {
        let m = ["planet" : "World", "population" : 7000000000]
        let feature = self.expectationWithDescription("Test")
        
        do {
            try WS.url("http://httpbin.org/post")
                .withHeaders(["Content-Type":"application/json"])
                .withBody(m)
                .withMethod("POST")
                .execute()
                .then { (res) -> Void in
                    let body = res.body
                    print(body)
                    let range = body.rangeOfString("{\\\"planet\\\":\\\"World\\\",\\\"population\\\":7000000000}")
                    XCTAssertNotEqual(range, nil)
                    feature.fulfill()
                }.error {err in
                    print(err)
                    XCTFail("Got error")
                    feature.fulfill()
            }
        } catch {
            XCTFail("Got exception")
        }
        self.waitForExpectationsWithTimeout(10) { (err) -> Void in
            if (err != nil) {
                XCTFail("Got timeout")
            }
        }
    }
    
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
}
