//
//  WS.swift
//  BGEiOSApp
//
//  Created by Bibhas Bhattacharya on 1/28/16.
//  Copyright © 2016 Bibhas Bhattacharya. All rights reserved.
//

import Foundation
import PromiseKit

/**
 WS is a class that simplifies asynchronous RESTful client development. It also adds
 retry of GET calls. It is modeled after the WS class of the Play framework.
*/
class WS {
    class func url(url: String) -> WSRequest {
        return WSRequest(url: url)
    }
}

class WSResponse {
    var raw : NSData
    var response:NSHTTPURLResponse
    
    init(data:NSData, res:NSHTTPURLResponse) {
        raw = data
        response = res
    }
    
    lazy var body: String = {
        String(data: self.raw, encoding: NSUTF8StringEncoding)!
    }()
    
    lazy var json:AnyObject? = self.jsonBuilder()
    
    func jsonBuilder() -> AnyObject? {
        var res : AnyObject? = nil
        
        do {
            res = try NSJSONSerialization.JSONObjectWithData(
                self.raw,
                options: NSJSONReadingOptions(rawValue: 0))
        } catch let error as NSError {
            print("Error parsing JSON \(error)")
        }
        
        return res
    }
}

class WSRequest {
    /**
    The maximum number of times a GET call is attempted in case of a network failure. Any failure
     indicated by a HTTP reply status code is not retried. Retry count for all methods other than GET is always 1.
    */
    var maxTries = 1

    private var retryCount = 0
    var url : NSURL
    var body : NSData?
    var headers = [String:String]()
    var method = "GET"
    /**
    Create a new WS object.
     
     - parameter url: The URL to send the request to.
    */
    init(url:String) {
        self.url = NSURL(string: url)!
    }
    
    func withBody(body: String) -> WSRequest {
        self.body = body.dataUsingEncoding(NSUTF8StringEncoding)
        
        return self
    }

    func withBody(body: AnyObject) throws -> WSRequest {
        self.body = try NSJSONSerialization.dataWithJSONObject(body, options: NSJSONWritingOptions(rawValue:0))
        
        self.headers["Content-Type"] = "application/json"
        
        return self
    }
    
    func withMethod(method: String) -> WSRequest {
        self.method = method
        
        return self
    }

    func withHeaders(headers : [String:String]) -> WSRequest {
        for (key, value) in headers {
            self.headers[key] = value
        }
        
        return self
    }
    
    /**
     Initiate a GET request. In case of a network error the GET call is retried upto ``maxTries`` times.
     
     - returns: A Promise object. In case of success this promise will return a String containing the body of the response.
     In case of error this promise will offer an NSError object.
    */
    func get() -> Promise<WSResponse> {
        maxTries = 5
        
        return self.withMethod("GET").execute()
    }

    func post(body:String) -> Promise<WSResponse> {
        maxTries = 1
        
        return self.withMethod("POST").withBody(body).execute()
    }

    func post() -> Promise<WSResponse> {
        maxTries = 1
        
        return self.withMethod("POST").execute()
    }
    
    func execute() -> Promise<WSResponse> {
        let session = NSURLSession.sharedSession()
        let request = NSMutableURLRequest(URL: url, cachePolicy: NSURLRequestCachePolicy.UseProtocolCachePolicy, timeoutInterval: 60.0)
        
        request.HTTPMethod = self.method
        
        if let bodyData = self.body {
            request.HTTPBody = bodyData
        }
        
        for (headerName, headerValue) in self.headers {
            request.addValue(headerValue, forHTTPHeaderField: headerName)
        }
        
        return Promise {fulfill, reject in
            let attempt = self.retryCount
            
            print("---Attempt: \(attempt)")
            
            let task = session.dataTaskWithRequest(request) { (data, response, error) -> Void in
                if (error == nil) {
                    let httpsResponse = response as! NSHTTPURLResponse
                    if (httpsResponse.statusCode < 400) {
                        fulfill(WSResponse(data: data!, res: httpsResponse))
                    } else {
                        reject(NSError(domain: "WS", code: 0, userInfo: ["message" :"Invalid status code: \(httpsResponse.statusCode)"]))
                    }
                } else {
                    print("WS error: \(error)")
                    
                    ++self.retryCount
                    if (self.retryCount < self.maxTries) {
                        print("---Retry: \(attempt)")
                        self.execute().then {body -> Void in
                            print("+++Fulfilling attempt: \(attempt)")
                            fulfill(body)
                        }.error {err in
                            print("+++Rejecting attempt: \(attempt)")
                            reject(err)
                        }
                    } else {
                        print("***Rejecting attempt: \(attempt)")
                        reject(error!)
                    }

                }
            }
            
            task.resume()
        }
    }
}