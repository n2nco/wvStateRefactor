//
//  MarionetteLite.swift
//  swiftRedux
//
//  Created by Blake  on 2020-03-10.
//  Copyright © 2020 b. All rights reserved.
//

import Foundation
import Foundation
import WebKit
import UIKit
import PromiseKit
import Signals


#if canImport(Cocoa)
import Cocoa
#endif
#if canImport(UIKit)
import UIKit
#endif

var HELPER_CODE = """
const nativeInputValueGetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').get
const nativeInputValueSetter = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set
const nativeTextAreaValueGetter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').get
const nativeTextAreaValueSetter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set
/* Native requestAnimationFrame doesn't work headless */
window['requestAnimationFrame'] = (function () {
    let last = 0
    let queue = []
    const frameDuration = 1000 / 60
    function rethrow (err) {
        throw err
    }
    function processQueue () {
        const batch = queue
        queue = []
        for (const fn of batch) {
            try {
                fn()
            } catch (err) {
                setTimeout(rethrow, 0, err)
            }
        }
    }
    return function requestAnimationFrame (fn) {
        if (queue.length === 0) {
            const now = performance.now()
            const next = Math.max(0, frameDuration - (now - last))
            last = (next + now)
            setTimeout(processQueue, Math.round(next))
        }
        queue.push(fn)
    }
}())
class TimeoutError extends Error {
    constructor (message) {
        super(message)
        this.name = 'TimeoutError'
    }
}
function sleep (ms) {
    return new Promise(resolve => setTimeout(resolve, ms))
}
function idle (min, max) {
    return sleep(Math.floor(min + (Math.random() * (max - min))))
}
window['SwiftMarionetteReload'] = function () {
    window.location.reload()
}
window['SwiftMarionetteSetContent'] = function (html) {
    document.open()
    document.write(html)
    document.close()
}
window['SwiftMarionetteSimulateClick'] = async function (selector) {
    const target = document.querySelector(selector)
    target.click()
}
window['SwiftMarionetteSimulateType'] = async function (selector, text) {
    const target = document.querySelector(selector)
    const getter = (target.tagName === 'TEXTAREA') ? nativeTextAreaValueGetter : nativeInputValueGetter
    const setter = (target.tagName === 'TEXTAREA') ? nativeTextAreaValueSetter : nativeInputValueSetter
    target.focus()
    await idle(50, 90)
    let currentValue = getter.call(target)
    for (const char of text) {
        const down = new KeyboardEvent('keydown', { key: char, charCode: char.charCodeAt(0), keyCode: char.charCodeAt(0), which: char.charCodeAt(0) })
        target.dispatchEvent(down)
        const press = new KeyboardEvent('keypress', { key: char, charCode: char.charCodeAt(0), keyCode: char.charCodeAt(0), which: char.charCodeAt(0) })
        target.dispatchEvent(press)
        const ev = new InputEvent('input', { data: char, inputType: 'insertText', composed: true, bubbles: true })
        currentValue += char
        setter.call(target, currentValue)
        target.dispatchEvent(ev)
        await idle(20, 110)
        const up = new KeyboardEvent('keyup', { key: char, charCode: char.charCodeAt(0), keyCode: char.charCodeAt(0), which: char.charCodeAt(0) })
        target.dispatchEvent(up)
        await idle(15, 120)
    }
    const ev = new Event('change', { bubbles: true })
    target.dispatchEvent(ev)
    target.blur()
}
window['SwiftMarionetteWaitForFunction'] = function (fn) {
    return new Promise((resolve, reject) => {
        let timedOut = false
        function onRaf () {
            if (timedOut) return
            if (fn()) return resolve()
            requestAnimationFrame(onRaf)
        }
        setTimeout(() => {
            timedOut = true
            reject(new TimeoutError(`Timeout reached waiting for function to return truthy`))
        }, 30000)
        onRaf()
    })
}
window['SwiftMarionetteWaitForSelector'] = function (selector) {
    if (document.querySelector(selector)) return Promise.resolve()
    return new Promise((resolve, reject) => {
        const observer = new MutationObserver((mutations) => {
            if (document.querySelector(selector)) {
                observer.disconnect()
                resolve()
            }
        })
        setTimeout(() => {
            observer.disconnect()
            reject(new TimeoutError(`Timeout reached waiting for "${selector}" to appear`))
        }, 30000)
        observer.observe(document, {
            childList: true,
            subtree: true,
            attributes: true
        })
    })
}
"""

open class MarionetteLite: NSObject, WKNavigationDelegate {
    public let bridge: JSBridge
    public let webView: WKWebView
    private let onNavigationFinished = Signal<WKNavigation>(retainLastData: true)
    private var resCookies: String?; //not certain correct type for 'Set-Cookies' header.
    private var pageTitle: String? //use to know when on new page using document.title.
    private var requestNumber: Int = 0
    private var responseNumber: Int = 0
    
   
    //This returns 'page' which contains above^ vars, most notably: page.webView.
    public override init() {
        bridge = JSBridge(libraryCode: HELPER_CODE, headless: false, incognito: true)
        webView = bridge.webView!
        super.init()
        webView.navigationDelegate = self
        webView.frame = CGRect(x: 0, y: 0, width: 1024, height: 768) //ensure non-zero frame size
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/72.0.3624.0 Safari/537.36";
    }
//Request Interception
   public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping
   (WKNavigationActionPolicy) -> Void) {
          
    requestNumber+=1
    print("New request intercepted. Request number: ", requestNumber)
   // dump(navigationAction.request)
    if (navigationAction.request.allowsExpensiveNetworkAccess == false) {
        print("This request does not allow expensive network acccess")
    }
//    print("main document url: ")
//    dump(navigationAction.request.mainDocumentURL)
    print("method ", navigationAction.request.httpMethod)
   // print("navigationAction.request.url") //see if contains FROMSIGNIN
    //print(navigationAction.request.url)
//       print("Dumping cookie store ")
//       dump(self.webView.configuration.websiteDataStore.httpCookieStore)
//
    if ((navigationAction.request.url?.absoluteString.contains("FROMSIGNIN"))!) {
           // not a GET or already a custom request - continue
           print("FROMSIGNING URL FOUND - dumping full request:")
           dump(navigationAction.request)
            //may want to intercept sign in here & do a shared data task?
        
//           decisionHandler(.allow) //can cancel & load this request separately
        // loadWebPage(url: navigationAction.request.url!)
//           return
       }
    if (((navigationAction.request.url?.absoluteString.contains("ClientSignin"))!)) {
        print("CLIENT SIGN IN MAIN REQUEST IN INTERCEPTION")
    }
    if(navigationAction.request.httpMethod! == "POST") {
        print("Hit Post Request") //does this unpack optional?
      //  dump(navigationAction.request)
    }

    // print("A GET or POST was intercepted.")
//       dump(navigationAction.request.url)
//       dump(navigationAction.request.allHTTPHeaderFields)
       
         decisionHandler(.allow)
           return
       //decisionHandler(.cancel)// cancels the request. i.e. if which to pass to a request contruction function.
   }
  
    // intercept, check, modify http requests. //https://stackoverflow.com/questions/28984212/how-to-add-http-headers-in-request-globally-for-ios-in-swift
    func loadWebPage(url: URL)  {
        var customRequest = URLRequest(url: url)
        //get "Set-Cookies" object, and set it here.
        //Uncertainty - as string or NSObject?
        customRequest.setValue(resCookies as! String, forHTTPHeaderField: "Set-Cookie") //
        webView.load(customRequest)
    }
   
    
    //Reponse Interception. - Send this cacheRecord deleting code to Linus?
    public func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        
       // print("Dumping navigationResponse.response")
       // print("Printing response url from navigationResponse:")
      // print(navigationResponse.response.url?.absoluteString)
        
        //JS sets cache/storage. So when should I delete cache/storage? Perhaps right before a .click()?
       // DispatchQueue.main.sync {
        
        
        //See if works without disbaling webcache? can recomment the following if doesn't work;
        
//            WebCache.setDisabled(true) //from binding.
//            let cacheRecords : Set<String> = [WKWebsiteDataTypeMemoryCache, WKWebsiteDataTypeFetchCache, WKWebsiteDataTypeDiskCache]
//            URLCache.shared.removeAllCachedResponses()
//            self.webView.configuration.websiteDataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
//                print("printing cache records")
//                dump(records)
//                records.forEach { record in     // Should I keep local+Session storage items? only deleting cache?
//                    //                        self.webView.configuration.websiteDataStore.removeData(ofTypes: record.dataTypes, for: [record], completionHandler: {})
//                    self.webView.configuration.websiteDataStore.removeData(ofTypes: cacheRecords, for: [record], completionHandler: {})
//                    print("record type:", record.dataTypes)
//                    print("[WebCacheCleaner] Record \(record) deleted")
//                    //WKWebsiteDataRecord.Type
//                }
//
//           // }
//
      
            if let response = navigationResponse.response as? HTTPURLResponse {
                let headers = response.allHeaderFields
               
                //dump(response.allHeaderFields)
               // print("response url: ", response.url)
                print("reponse status code: ", response.statusCode)
                //            let cType : NSMutableString = headers["Content-Type"] as! NSMutableString
                ////                print("headers")
                ////                dump(headers)
                //                print("cType")
                //                print(cType)
                //            if (cType.contains("charset=ISO-8859-1")) {
                //                print("found etransfer response")
                //            }
                //do something with headers
            }
      //  }
        
      //  let headers = (HTTPURLResponse: navigationResponse.response.allHeaderFields);
        decisionHandler(.allow)
       // decisionHandler(.cancel)
    }
    public func webView(_ webView: WKWebView, s navigation: WKNavigation) {
          UIApplication.shared.isNetworkActivityIndicatorVisible = true
          print("didStartProvisionalNavigation: \(navigation)")
        //  dump(navigation)
      }

    //Server redirect intercept
    public func webView(_ webView: WKWebView,
                          didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("didReceiveServerRedirect: \(navigation)")
       // print(navigation)
    }
    
      ///"https://www.hackingwithswift.com/articles/112/the-ultimate-guide-to-wkwebview"
        @objc //Important: This is the didFinish navigation function. must fire event.
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("didFinishNavigation called - ON NEW PAGE- firing to let subscribers (goto() & whenNavFinshed() know")
            self.onNavigationFinished.fire(navigation);
            print("page title: ", getPT())
            print("Number of pages hit: ", onNavigationFinished.fireCount)
          
            print("Current WebView URL:", self.webView.url!);
 
            print("Current (could become previous after the response to this req.) Page title:");
            print(self.webView.title);
            self.pageTitle = self.webView.title // for use in page title change timer  func
    //        WebCache.setDisabled(true)
    //        let cacheRecords : Set<String> = [WKWebsiteDataTypeMemoryCache, WKWebsiteDataTypeFetchCache, WKWebsiteDataTypeDiskCache]
    //               WKWebsiteDataStore.default().fetchDataRecords(ofTypes: cacheRecords) { records in
    //                   print(records)
    //               }
            //        print(self.webView.serverTrust)
            
            //Example of completion handler usage for reference - will use later:
            //        func checkTitle (_ webView: WKWebView, completion: @escaping (_ titleString: String?) -> Void) {
            //            webView.evaluateJavaScript("document.title", completionHandler: { (innerHTML, error ) in
            //                // logic to apply to callback's agument (i.e. innerHTML)
            //                print("evaluateJS completion handler--------");
            //                completion(innerHTML as? String) //
            //            })
            //        }
            //        checkTitle(self.webView) { html in
            //            print("checkTitle call-------");
            //            print(html)
            //        }
//            if url.contains("wps/myportal/") {
//                print("-----inside RBC account")
//            }
            //     if let url = webView.url, let host = url.host {
            //             if (url.path == loginPath) {
            //                   if let username = self.username, let password = self.password {
            //                       let js = String(format: "js script", username, password)
            //                       webView.evaluateJavaScript(js, completionHandler: nil)
            //                   }
            //               } else if (url.path == "error path") {
            //                   // Login failed
            //               }
                   }
    
        //public api:
    public func goto(_ url: URL) -> Promise<Void> {
       ///Perhaps I should move this to didFinishNavigation
        
//        let cacheRecords : Set<String> = [WKWebsiteDataTypeMemoryCache, WKWebsiteDataTypeFetchCache]
//        WKWebsiteDataStore.default().fetchDataRecords(ofTypes: cacheRecords) { records in
//            print(records)
//        }
        
//        var webCache : WebCache = WebCache;
//          webCache.setDisabled();
       // WebCache.setDisabled(true) //invoke here or obj. c?
        //WebCache.disabled(true)
       // let mutableURLRequest = NSMutableURLRequest(url: url)
        //mutableURLRequest.httpMethod = "POST"
       //    mutableURLRequest.setValue("application/json",  forHTTPHeaderField: "ContentNSURLRequest.CachePolicyURLRequest.cachePolicy = NSURLRequestCachePolicy.ReloadIgnoringCacheData")
        //mutableURLRequest.HTTPBody = self.createJson()
        // request(mutableURLRequest).validate().responseJSON{ response in...
      
        ///current working - re-comment
        let promise = self.waitForNavigation()
       //ß webView.load(URLRequest(url: url))
       
        webView.load(URLRequest(url: url, cachePolicy: NSURLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData))
        return promise
//        task.resume()
//        semaphore.wait()
//        return promise
//    }
        return signIn(promise)
        
        }
    func signIn(_ promise : Promise<Void>) -> Promise<Void> {
        //where request-based eTrasfer code lives.
        return promise
    }

    public func quickSnap() -> Promise<UIImage> {
        let config = WKSnapshotConfiguration()
        config.afterScreenUpdates = true
        config.rect = CGRect(x: 100, y: 100, width: 1050, height: 1050)
        return Promise { seal in self.webView.takeSnapshot(with: config, completionHandler: seal.resolve) }
    }
    
    public func waitForNavigation() -> Promise<Void> {
        print("subscribed to waiting for navigation")
        return Promise { seal in self.onNavigationFinished.subscribeOnce(with: self) { _ in seal.fulfill(()) } }
    }
    public func type(_ selector: String, _ text: String) -> Promise<Void> {
        return self.bridge.call(function: "SwiftMarionetteSimulateType", withArgs: (selector, text)) as Promise<Void>
    }

    private func getPT() -> String {
        return self.webView.title!
    }
    
    //not in use:
    public func waitForNewPT() -> Promise<Void> {
        let localPrevPT = self.pageTitle
        var result : Bool = false;
        print("inside wait for new page title. Current page title:")
        print(localPrevPT!)
        print("new PT:")
        print(getPT())
        var repeats : Int = 0
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if (localPrevPT! != self.webView.title)  {
                timer.invalidate()
                result = true
//                return Promise { seal in seal.fulfill((true))  }
            }
            repeats+=1
            
        }
        print("returning from wait for new PT")
        return Promise { seal in seal.fulfill(()) }
    }
    
    public func evaluate(_ script: String) -> Promise<Void> {
        // self.webView.evaluateJavascript("string")
        return bridge.call(function: "() => { return \(script)\n }")
    }
    
    public func quickEvaluate( _ script: String) -> Promise<String> {
        return Promise<String> { seal in
            self.webView.evaluateJavaScript(script, completionHandler: { (result, error) in
                   if error != nil {
                       print(error)
                   }
                
                   
                    if result != nil {
                        print(result)
                        if result is Bool {
                          return  seal.fulfill(String(true))
                        }
                       return seal.fulfill(String(result as! String))
                    }
                   })
                // can also seal.reject(error), seal.resolve(value, error)
            }
        }

    #if canImport(Cocoa)
//    public func screenshot() -> Promise<NSImage> {
//        return Promise { seal in self.webView.takeSnapshot(with: nil, completionHandler: seal.resolve) }
//    }
    #endif
    
    #if canImport(UIKit)
    public func screenshot() -> Promise<UIImage> {
        return Promise { seal in self.webView.takeSnapshot(with: nil, completionHandler: seal.resolve) }
    }
    #endif
        
// Do any additional setup after loading the view, typically from a nib.
    
    
}
