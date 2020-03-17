//
//  WebView.swift
//  swiftRedux
//
//  Created by Blake  on 2020-03-11.
//  Copyright © 2020 b. All rights reserved.
//

import Foundation
import WebKit
import SwiftUI
import SwiftUIFlux


struct WebView: UIViewRepresentable {
    @EnvironmentObject var store: Store<AppState>
    
    //can delete this:
    enum WVState: String {
        case initial
        case done
        case working
        case errorOccurred
    }
    @State var wvState : WVState = .initial //default initalized.
    //@State var url: URL //constructor initalized.
    
    var wv : WKWebView?
    
    //can make use of this init if using multiple webviews (i.e. td & rbc simultaneous) perhaps.
    init() {
        //  self._url = State(initialValue: url) //https://stackoverflow.com/a/58137096/9537752
    }
    
    //seems JSBridge overrode Context. Perhaps try changing name of JSBridge's context?
    //@Binding var url: URL?
    func makeUIView(context: Context) -> WKWebView {
        //what is store var here?
        let webView = store.state.page!.webView as WKWebView //self doesn't work here perhaps?
        
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {

    }
    
    func makeCoordinator() -> Coordinator {
        //logic to select coordinator based on Site struct name.
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            self.parent.wvState = .working
            print("did start provisional on webview: ")
            dump(webView)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            self.parent.wvState = .errorOccurred
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.parent.wvState = .done
        }
        
        init(_ parent: WebView) {
            self.parent = parent
        }
    }
}
