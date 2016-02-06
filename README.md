# WSKit
WSKit is a HTTP client library that attempts to reproduce the [Play WS API](https://www.playframework.com/documentation/2.5.x/api/scala/index.html#play.api.libs.ws.package) 
in Swift. It has two key features:

- A promise based API for easier asynchrnous HTTP communication.
- Provides a retry mechanism for GET requests in case of network communication errors. This is important for mobile applicatins where
network connection can be unreliable.

### Example
A simple GET request.

```swift
WS.url("http://httpbin.org/get").get()
    .then { (res) -> Void in
        let body = res.body()
        print(body)
    }.error {err in
        print(err)
    }
```

Where ``res`` is a ``WSResponse`` object. And ``err`` is ``NSError``. An error occurs in case of a network problem or if the response 
status code is more than ``400``.

A simple POST example:

```swift
WS.url("http://httpbin.org/post")
    .withHeaders(["Content-Type":"application/json"])
    .post("{'hello':'mama'}")
    .then { (res) -> Void in
        let body = res.body()
        print(body)
    }.error {err in
        print(err)
    }
```