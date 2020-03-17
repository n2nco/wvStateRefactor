//
//  NavLib.swift
//  swiftRedux
//
//  Created by Blake  on 2020-03-10.
//  Copyright © 2020 b. All rights reserved.
//

import Foundation
import PromiseKit

//always
//on subsequent attempts, try stored credentials - if fails, always inject rbcCredsCapture.

//var gPage : MarionetteLite? //global scope reference to MLite instance.
//func createPage() -> MarionetteLite {
//    gPage = MarionetteLite() //class type that is WKNavigator.
//    return gPage! //page.webView = WKWebview.
//}


var u : String?
var p : String?

func showWebView() {
   // DispatchQueue.main.async {
        store.dispatch(action: AppActions.ChangeScene(newScene: .showingWebView))
  // }
}
func showSending() {
    store.dispatch(action: AppActions.ChangeScene(newScene: .sending))
}


func credsSet() -> Bool {
    //if creds are set is NOT true, change credsSet = false
     if store.state.userState.credentialsSet { //computed property.
         u = store.state.userState.rbcUsername
         p = store.state.userState.rbcPassword
         return true
     } else { //if creds set. a) trigger alert b) use empty strings for simplicity.
         u = "" //defaults
         p = ""
       return false
     }
}

func attemptRbcLogin(needToGetCreds: Bool = false) {
    if credsSet() || needToGetCreds {
        firstly {
             store.state.page!.goto(URL(string: "https://www1.royalbank.com/cgi-bin/rbaccess/rbcgi3m01?F6=1&F7=IB&F21=IB&F22=IB&REQUEST=ClientSignin&LANGUAGE=ENGLISH&_ga=2.142611827.717899448.1581641814-1982597706.1581288543")!)
             //NOTE: goto subsribes to wait for navigation.
         }.then { data -> Promise<String> in
             // something that should only happen if xyz is not nil
             store.state.page!.quickEvaluate("document.querySelector(\"#K1\").value = '\(u ?? "")';")
         }.then { data -> Promise<String> in
            store.state.page!.quickEvaluate("document.querySelector(\"#Q1\").value = '\(p ?? "")';")
         }
         //.then { data -> Promise<Void> in
         .done {  ready in
             store.state.page!.quickEvaluate("document.querySelector(\".yellowBtnLarge\").click();")
         }
    }
    else {
        store.dispatch(action: AppActions.CredsNotSet(nowSet: false)) //ensure this is false (redundant but perhaps useful)
    }
}

//if user clicks pay & is not on AccountSummary as determined by Context.swift, show webview.


//can change these to quickEvaluate

func accountSummaryOnward() {
     //can move this to action.
    let page = store.state.page!
    let name = store.state.recipName
    let email =  store.state.recipEmail
    let amount = String(store.state.amountToSend)
    
    print(amount)
    let msgBody = store.state.cart // to do.
    
    firstly {
        page.evaluate("document.querySelector(\"a[ga-event-label='Send an Interac eTransfer']\").click();")
    }
    
    .then {
        page.waitForNavigation()
    }.done { ready in
       // page.quickEvaluate("document.querySelector(\"#amount\").value = 20;")
          transferOnward()  //MARK: should be called via context.swift -> action
    }
  //temp call location
    
}


func transferOnward() {
    let page = store.state.page!
    let amount = String(store.state.amountToSend)
   
    let email =  store.state.recipEmail!
    
    firstly {
        page.evaluate("document.querySelector(\"#amount\").value = '\(amount)';")
    }.then { data in
        page.evaluate("document.querySelector(\"[ga-event-label='Submit Button']\").click();")
        
    }.then {
        page.waitForNavigation()
    }.done { data in
       sendPageOnward()
    }
    
}
func sendPageOnward() {
    let page = store.state.page!
    let amount = String(store.state.amountToSend)
    let name: String = store.state.recipName ?? "Anon"
    let email: String =  store.state.recipEmail!
    
    firstly {
        page.quickEvaluate("document.querySelector(\"#EMT_NAME_ID\").value = '\(name)';")
    }.then { data -> Promise<String> in
        page.quickEvaluate("document.querySelector(\"#EMT_EMAILADDRESS_ID\").value = '\(email)';")
    }.then { data -> Promise<String> in
        page.quickEvaluate("document.querySelector(\"#EMT_EMAILADDRESS_ID\").dispatchEvent(new Event('mousedown', { bubbles: true }));")
    }.then { data in
        page.evaluate("document.querySelector(\"#EMT_EMAILADDRESS_ID\").dispatchEvent(new Event('blur', { bubbles: true }));")
    }.then {
        page.evaluate("document.Form_3MBPAEMTENT_BPAInfo.submit();")
    }.then {
        page.waitForNavigation()
    }.then {
        page.evaluate("document.querySelector(\"#EMT_QUESTION_ID\").value = 'Which app was used to send this?';")
    }.then {
        page.evaluate("document.querySelector(\"#EMT_RESPONSE_ID\").value = 'intr';")
    }.then {
        page.evaluate("document.querySelector(\"#EMT_CONFIRM_RESPONSE_ID\").value = 'intr';")
    }       //MARK:FOR TESTING, DON'T CLICK CONFIRM SUMBIT
//    .then {

//        page.evaluate("document.Form_3MBPAEMTVFY_Confirm.submit()") //Can test for est event listener breakpoints here if erroring at some point.
//    }
//    .then {
//        page.waitForNavigation()
  .then { data in
    page.screenshot()
    }
    .done { image in
        //call func with img, and save it. https://stackoverflow.com/a/56975878/9537752
        let name: String = "confirmed_screenshot"
        let imgSaved = saveImage(image: image, fileName: name)
 
        if !imgSaved {
            print("cound not save img")
        }
       // store.dispatch(action: AppActions.ScreenshotSaved(image: image, fileName: fullFileName)) this action is dispatched in saveImg function
    }
}


