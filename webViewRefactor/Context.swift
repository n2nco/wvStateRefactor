import WebKit
import PromiseKit

#if os(iOS)
import UIKit
#endif
//MARK: Temporary - b
var firstPageHit = false

public struct AbortedError: Error {}

public struct JSError: Error, Codable {
    public let name: String
    public let message: String
    public let stack: String

    public let line: Int
    public let column: Int

    public let code: String?
}

fileprivate extension JSError {
    init(fromDictionary error: Dictionary<String, AnyObject>) {
        self.init(
            name: (error["name"] as? String) ?? "Error",
            message: (error["message"] as? String) ?? "Unknown error",
            stack: (error["stack"] as? String) ?? "<unknown>",
            line: (error["line"] as? Int) ?? 0,
            column: (error["column"] as? Int) ?? 0,
            code: (error["code"] as? String)
        )
    }
}

fileprivate let defaultOrigin = URL(string: "bridge://localhost/")!
fileprivate let html = "<!DOCTYPE html>\n<html>\n<head></head>\n<body></body>\n</html>".data(using: .utf8)!
fileprivate let notFound = "404 Not Found".data(using: .utf8)!

fileprivate let internalLibrary = """

(function () {
    function serializeError (value) {
        return (typeof value !== 'object' || value === null) ? {} : {
            name: String(value.name),
            message: String(value.message),
            stack: String(value.stack),
            line: Number(value.line),
            column: Number(value.column),
            code: value.code ? String(value.code) : null
        }
    }

    let nextId = 1
    let callbacks = {}


    window.addEventListener('pagehide', () => {
        webkit.messageHandlers.scriptHandler.postMessage({ didUnload: true })
    })

    window.__JSBridge__resolve__ = function (id, value) {
        callbacks[id].resolve(value)
        delete callbacks[id]
    }

    window.__JSBridge__reject__ = function (id, error) {
        callbacks[id].reject(error)
        delete callbacks[id]
    }

    window.__JSBridge__receive__ = function (id, fnFactory, ...args) {
        Promise.resolve().then(() => {
            return fnFactory()(...args)
        }).then((result) => {
            webkit.messageHandlers.scriptHandler.postMessage({ id, result: JSON.stringify(result === undefined ? null : result) || 'null' })
        }, (err) => {
            webkit.messageHandlers.scriptHandler.postMessage({ id, error: serializeError(err) })
        })
    }

    window.__JSBridge__send__ = function (method, ...args) {
        return new Promise((resolve, reject) => {
            const id = nextId++
            callbacks[id] = { resolve, reject }
            webkit.messageHandlers.scriptHandler.postMessage({ id, method, params: args.map(x => JSON.stringify(x)) })
        })
    }

    window.__JSBridge__ready__ = function (success, err) {
        if (success) {
            webkit.messageHandlers.scriptHandler.postMessage({ didLoad: true })
        } else {
            webkit.messageHandlers.scriptHandler.postMessage({ didLoad: true, error: serializeError(err) })
        }
    }
}())
"""

//get creds. notify when on online banking (valid creds)
fileprivate let source2 =
"""
console.log('test');
if (document.title.includes("Sign In to Online Banking")) { if (document.querySelector(".yellowBtnLarge")) {
console.log("inside capturepostmsg func");
document.querySelector(".yellowBtnLarge").addEventListener("click", function(){ username =
  document.querySelector("#K1").value; password = document.querySelector("#Q1").value;
  webkit.messageHandlers.creds.postMessage({ username: username, password: password } ) })} };


if (document.title.includes("Accounts Summary - RBC Online Banking")) {
console.log("hit an account summary page!");
webkit.messageHandlers.page.postMessage({ onPage: "AccountSummary" } )};
"""

fileprivate let source3 =
"""
if ( document.querySelector("a[title='Print this page']") != null  ) {
    webkit.messageHandlers.page.postMessage( { onPage: "Complete" } )
}
"""

//Does not work on mobile, html not in page:
//var pEls = document.evaluate("//p[contains(normalize-space(text()), 'We were expecting a different answer.')]", document, null, XPathResult.ANY_TYPE, null );
//var pEl = pEls.iterateNext();
//if (pEl != null) {
//    webkit.messageHandlers.page.postMessage( { onPage: “LoginFail” } );
//};


@available(iOS 11.0, macOS 10.13, *)
fileprivate class BridgeSchemeHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        let url = urlSchemeTask.request.url!

        if url.path == "/" {
            urlSchemeTask.didReceive(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [
                "Content-Type": "text/html; charset=utf-8",
                "Content-Length": String(html.count),
            ])!)
            urlSchemeTask.didReceive(html)
        } else {
            urlSchemeTask.didReceive(HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: [
                "Content-Type": "text/plain; charset=utf-8",
                "Content-Length": String(notFound.count),
            ])!)
            urlSchemeTask.didReceive(notFound)
        }

        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

@available(iOS 11.0, macOS 10.13, *)
fileprivate func buildWebViewConfig(libraryCode: String, incognito: Bool) -> WKWebViewConfiguration {
    let source = "\(internalLibrary);try{(function () {\(libraryCode)}());__JSBridge__ready__(true)} catch (err) {__JSBridge__ready__(false, err)}"
    let script = WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    let script2 = WKUserScript(source: source2, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
    let script3 = WKUserScript(source: source3, injectionTime: .atDocumentEnd, forMainFrameOnly: true)

    let controller = WKUserContentController()
    let configuration = WKWebViewConfiguration()
    
    //inject this:
    //add this to button click event listener: webkit.messageHandlers.scriptHandler.postMessage({ credentials: {username: username, password: password} })
    //watch for message.body containing credentials

    controller.addUserScript(script)
    controller.addUserScript(script2)
    controller.addUserScript(script3)
    
    configuration.userContentController = controller
    configuration.setURLSchemeHandler(BridgeSchemeHandler(), forURLScheme: "bridge")

    if incognito {
        configuration.websiteDataStore = .nonPersistent()
    }
    return configuration
}

var oneErrorCaught: Bool = false

@available(iOS 11.0, macOS 10.13, *)
internal class JBContext: NSObject, WKScriptMessageHandler {
    private var (ready, readyResolver) = Promise<Void>.pending()

    private var nextIdentifier = 1
    private var handlers = [Int: Resolver<String>]()

    private var functions = [String: ([String]) throws -> Promise<String>]()

    private static var errorEncoder = JSONEncoder()

    internal let webView: WKWebView

    init(libraryCode: String, customOrigin: URL?, incognito: Bool) {
        webView = WKWebView.init(frame: CGRect(x: 0, y: 0, width: 500, height: 500), configuration: buildWebViewConfig(libraryCode: libraryCode, incognito: incognito))

        super.init()

        webView.configuration.userContentController.add(self, name: "scriptHandler")
        webView.configuration.userContentController.add(self, name: "creds")
        webView.configuration.userContentController.add(self, name: "page")
        
        webView.load(html, mimeType: "text/html", characterEncodingName: "utf8", baseURL: customOrigin ?? defaultOrigin)
    }

    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
       //b
       // pick up on postMessages sent to creds. Set Appstate creds.
        //Note: could inject large if/else js on every single page and processes messages here (as alternative to using library directly).

        print(type(of: message.name))
        print("message.name")
        print(message.name)
        print(message.body)

       if message.name as? String == "creds" {
            guard let dict = message.body as? Dictionary<String, AnyObject> else { return }
            print(dict["username"]!)
            print(dict["password"]!)
            //Just grab & save creds every single time (even if inputting from existing?). (make conditional if this turns out to slow things down.
            //cases
            //1) users 1st time.
            //2) exisiting user, changed their creds (stored creds fail)
            //3) existing user, creds succeed.
           
            //Easiest way: on 'OnAccountSummary' store the creds.
        
            store.dispatch(action: UserActions.SetUsername(rbcUsername: (dict["username"] as? String ?? "")))
            store.dispatch(action: UserActions.SetPassword(rbcPassword: (dict["password"] as? String ?? "")))
        }

        
        if message.name as? String == "page" {
        guard let dict = message.body as? Dictionary<String, AnyObject> else { return }
            print("received msg from page channel----------")
            print(message.body)
            
            //THIS DOES NOT WORK
            if dict["onPage"]! as! String == "LoginFail" {
               print("Context.js has identified account summary page.")
               store.dispatch(action: WvActions.OnPage(page: .login))
               store.dispatch(action: UserActions.CredsValid(valid: false)) //set valid b4 accountsum action saves userstate.
//                store.dispatch(action: AppActions.OnAccountSummary()) //saves user creds to keychain.
//                store.dispatch(action: AppActions.CredsNotSet(nowSet: true)) //don't need this?
              
           }
            
            //MARK: Best single source of truth for where webview is.
            if dict["onPage"]! as! String == "AccountSummary" {
                print("Context.js has identified account summary page.")
                store.dispatch(action: WvActions.OnPage(page: .accountSummary))
                store.dispatch(action: UserActions.CredsValid(valid: true)) //set valid b4 accountsum action saves userstate.
//                store.dispatch(action: AppActions.OnAccountSummary()) //saves user creds to keychain.
//                store.dispatch(action: AppActions.CredsNotSet(nowSet: true)) //don't need this?
               
            }
       
            //MARK: todo
            //if dict["inPage]! as! String == "invalid login ~" {
//            store.dispatch(action: UserActions.CredsValid(valid: false)) // then will show invalid creds text.
//            }
           
            
            if dict["onPage"] as? String == "Complete" {
                store.dispatch(action: AppActions.TransferComplete()) //MARK: this is where transfer complete SHOULD be invoked. for now to test pre-complete, invoked in navlib (or fund in store?).
                
            }
        }
        
       //assign all other postMessages to a dict.
       guard let dict = message.body as? Dictionary<String, AnyObject> else { return }
       print(dict)
        if let messageBody = message.body as? [String: Any] {
            dump(message)
        }
        
        //MARK: temporary - b
        if let didLoad = dict["didLoad"] as? Bool, didLoad {
            if let error = dict["error"] as? Dictionary<String, AnyObject> {
                readyResolver.reject(JSError(fromDictionary: error))
            } else {
                readyResolver.fulfill(())
                if !firstPageHit {
                    store.dispatch(action: WvActions.OnPage(page: .none))
                    firstPageHit = true
                }
            }
        }

        if let didUnload = dict["didUnload"] as? Bool, didUnload {
            handlers.forEach { $1.reject(AbortedError()) }
            handlers.removeAll()
            (ready, readyResolver) = Promise<Void>.pending()
        }

        guard let id = dict["id"] as? Int else { return }
        if let result = dict["result"] as? String {
            guard let handler = handlers.removeValue(forKey: id) else { return }

            return handler.fulfill(result)
        }
        
        if let error = dict["error"] as? Dictionary<String, AnyObject> {
            guard let handler = handlers.removeValue(forKey: id) else { return }
            if !oneErrorCaught{
                //MARK: error on 2nd run = dispatch action that clicks log out & restarts transfer. or just click log out after complete every time.
               // createSecondStore()
                store.dispatch(action: AppActions.InitRBCTransfer())
                store.dispatch(action: AppActions.ChangeScene(newScene: .showingWebView))
            }
            if oneErrorCaught {
                store.dispatch(action: AppActions.ChangeScene(newScene: .showingWebView))
            }
            oneErrorCaught = true
            return handler.reject(JSError(fromDictionary: error))
        }

        if let method = dict["method"] as? String {
            guard let fn = functions[method] else { return }
            let params = dict["params"] as? [String] ?? []

            firstly {
                try fn(params)
            }.done {
                self.webView.evaluateJavaScript("__JSBridge__resolve__(\(id), \($0))")
            }.catch {
                if let error = $0 as? JSError, let encoded = try? JBContext.errorEncoder.encode(error), let props = String(data: encoded, encoding: .utf8) {
                    self.webView.evaluateJavaScript("__JSBridge__reject__(\(id), Object.assign(new Error(''), \(props)))")
                } else {
                    self.webView.evaluateJavaScript("__JSBridge__reject__(\(id), new Error('\($0.localizedDescription)'))")
                }
            }
        }
    }

    private func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
        firstly {
            self.ready
        }.done {
            self.webView.evaluateJavaScript(javaScriptString, completionHandler: completionHandler)
        }.catch {
            completionHandler?(nil, $0)
        }
    }

    internal func rawCall(function: String, args: String) -> Promise<String> {
        return Promise<String> { seal in
            let id = self.nextIdentifier
            self.nextIdentifier += 1
            self.handlers[id] = seal

            self.evaluateJavaScript("__JSBridge__receive__(\(id), () => \(function), ...[\(args)])") {
                if let error = $1 { seal.reject(error) }
            }
        }
    }

    internal func register(namespace: String) {
        self.evaluateJavaScript("window.\(namespace) = {}")
    }

    internal func register(functionNamed name: String, _ fn: @escaping ([String]) throws -> Promise<String>) {
        self.functions[name] = fn
        self.evaluateJavaScript("window.\(name) = (...args) => __JSBridge__send__('\(name)', ...args)")
    }
}
