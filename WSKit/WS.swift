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
public class WS {
    /**
     Constructs a new WSRequest object.
     
     - parameter url: The URL string
    */
    public class func url(url: String) -> WSRequest {
        return WSRequest(url: url)
    }
}

public class WSResponse {
    /**
     The raw response data.
    */
    public var raw : NSData
    /**
     The underlying NSHTTPURLResponse object.
    */
    public var response:NSHTTPURLResponse
    
    init(data:NSData, res:NSHTTPURLResponse) {
        raw = data
        response = res
    }
    
    /**
     This property converts the response body into a String.
    */
    public lazy var body: String = {
        String(data: self.raw, encoding: NSUTF8StringEncoding)!
    }()
    
    /**
     This property parses the response body into a JSON.
     */
    public lazy var json:AnyObject? = self.jsonBuilder()
    
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

public class WSRequest {
    /**
     The maximum number of times a GET call is attempted in case of a network failure. Any failure
     indicated by a HTTP reply status code is not retried. Retry count for all methods other than GET is always 1.
     */
    public var maxTries = 1
    
    private var retryCount = 0
    /**
    The URL for this request.
    */
    public var url : NSURL
    /**
    The body data for this request. Normally you should call the withBody() method to set the body.
    */
    public var body : NSData?
    /**
    The HTTP request headers.
    */
    public var headers = [String:String]()
    /**
     The HTTP request method. By default it is GET.
     */
    public var method = "GET"
    /**
     Create a new WS object.
     
     - parameter url: The URL to send the request to.
     */
    init(url:String) {
        self.url = NSURL(string: url)!
    }
    
    /**
     Sets the request body to a String. This method will convert the supplied String into NSData using UTF-8 encoding.
     
     - parameter body: The request body is set to this.
     */
    public func withBody(body: String) -> WSRequest {
        self.body = body.dataUsingEncoding(NSUTF8StringEncoding)
        
        return self
    }
    
    /**
     Sets the request body to a JSON document. This method will convert the supplied JSON object (array or dictionary) into NSData.
     
     - parameter body: The request body is set to this JSON document.
     */
    public func withBody(body: AnyObject) throws -> WSRequest {
        self.body = try NSJSONSerialization.dataWithJSONObject(body, options: NSJSONWritingOptions(rawValue:0))
        
        self.headers["Content-Type"] = "application/json"
        
        return self
    }
    /**
     Sets the request method. By default it is GET.
     
     - parameter method: The request method.
    */
    public func withMethod(method: String) -> WSRequest {
        self.method = method
        
        return self
    }
    
    /**
     Sets the request headers.
     
     - parameter headers: The request headers dictionary.
    */
    public func withHeaders(headers : [String:String]) -> WSRequest {
        for (key, value) in headers {
            self.headers[key] = value
        }
        
        return self
    }
    
    /**
     Executes a GET request. In case of a network error the GET call is retried upto ``maxTries`` times.
     
     - returns: A Promise object. In case of success this promise will return a WSResponse object. In case of error this promise will offer an NSError object.
     */
    public func get() -> Promise<WSResponse> {
        maxTries = 5
        
        return self.withMethod("GET").execute()
    }
    
    /**
     Executes a POST request. This method takes the request body as a parameter as a convenience so that you don't have to call withBody().
     
     - parameter body: Sets the request body to this String.
     - returns: A Promise object. In case of success this promise will return a WSResponse object. In case of error this promise will offer an NSError object.
     */
    public func post(body:String) -> Promise<WSResponse> {
        maxTries = 1
        
        return self.withMethod("POST").withBody(body).execute()
    }
    
    /**
     Executes a POST request. You must set the request body prior by calling withBody().
     
     - returns: A Promise object. In case of success this promise will return a WSResponse object. In case of error this promise will offer an NSError object.
     */
    public func post() -> Promise<WSResponse> {
        maxTries = 1
        
        return self.withMethod("POST").execute()
    }
    
    /**
     Executes an HTTP request. Normally you will call get() or post() to execute a request. This method is called to issue other types of requests like PUT and DELETE. This method also gives you completely flexibility. For example you can enable retries for non-GET requests. Although it is generally discouraged unless the request is idempotent.
     
     - returns: A Promise object. In case of success this promise will return a WSResponse object. In case of error this promise will offer an NSError object.
     */
    public func execute() -> Promise<WSResponse> {
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