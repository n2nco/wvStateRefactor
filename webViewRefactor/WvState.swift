//
//  WvState.swift
//  webViewRefactor
//
//  Created by Blake  on 2020-03-14.
//  Copyright © 2020 b. All rights reserved.
//

import Foundation
import SwiftUIFlux
import PromiseKit


   //New User:
   //AppState.Bank -> createPage -> attemptLogigin.fail -> Peer vs. Merchant -> showWv to get creds -> page.accountSummary - eTransfer.
   
   //Existing user:
   //AppState.Bank -> createPage -> attemptLogin.success (fail = merge into flow above) -> Peer vs. Merchant on click -> eTransfer

   //All: on error (insufficient balance): showWv, then pick up where left off.
   //All: option to 'cancel' and reset to blank state.
   

var wvNav = WvNav() // ensure wvNav is created after appstate's page is set.

struct WvState: FluxState  {

    public enum Bank: String  {
        case rbc, td
    }
    public enum Page: String  {
           case none, login, secQuestion, accountSummary, transferOccuring, complete
       }
     public enum WvAction: String  {
         case showWv, attemptLogin, checkBalance, eTransfer, complete
     }
    
    //Page
    //Assume appstate.bank = .rbc for now. can add additional switch later.
    var page: Page = .none {
          didSet {
            switch page { //oldValue = what page was previously.
            case .none:
                wvNav.attemptRLogin() //MARK: wvNav.attemptRLogin() This func works to take you back to the account summary page & await.
            case .login: //login failed detection does not work. couble increment page title count instead. (but don't nes. need this).
                print("on loginFailed page")
            case .secQuestion:
                print("page: security Q")
            case .accountSummary:
                store.dispatch(action: AppActions.OnAccountSummary()) //Saves creds to UserState.
               print("page: accountsummary wvstate - setting to refresh this page")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { //setToRefresh must be called after state has updated so that .accountsummary = true. tf, back of queue.
                    wvNav.setToRefresh()
                }
            case .transferOccuring:
                print("page: transfer occuring")
            case .complete:
                print("complete")
            
            }
        }
    }
    init() {
        
    }
}

//Make new Page logic based on WvState and AppState.
//Then the new page value on set pushes the process forward.
func wvStateReducer(state: WvState, action: Action) -> WvState {
    var state = state
    switch action {
    case let action as WvActions.OnPage:
        state.page = action.page
        
    case let action as WvActions.InitPay:
        wvNav.accountSummaryOnward()
    case let action as WvActions.BackToAcctSumm:
        wvNav.attemptRLogin()
    default:
          break
      }
      return state
}

struct WvActions {
    struct OnPage:Action {
        let page: WvState.Page
    }
    struct InitPay:Action {
        
    }
    struct BackToAcctSumm:Action {

    }
    struct ShowWv:Action {

    }
}

//can extend this class to include all the navlib functions. just don't ensure page is a singleton.

class WvNav {
    //MARK: reference all state through main store only?
    var page: MarionetteLite? = gpage //ensure always referencing store page.
    //var wvState: WvState? = store.state.wvState //
   
    init() { //MarionetteLite = class. so ref type.
     //   self.WvState = wvState // would this assignment create a copy that would f things up?
        
    }
    @objc func refresh() {
        if store.state.wvState.page == .accountSummary {
            page?.evaluate("location.reload()") //works
        }
    }
    func setToRefresh() {
        print(store.state.wvState.page)
        if store.state.wvState.page == .accountSummary {
            Timer.scheduledTimer(timeInterval: 90, target: self, selector: #selector(refresh), userInfo: nil, repeats: true) // refresh every 90s
        }//every 30 sec
    }
}

extension WvNav {
    func showWebView() {
            store.dispatch(action: AppActions.ChangeScene(newScene: .showingWebView))
    }
    
    func attemptRLogin() {
        var u:String = store.state.userState.rbcUsername ?? ""
        var p:String = store.state.userState.rbcPassword ?? ""
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
                 }.catch { _ in
                    self.showWebView()
                 }
            }
    
    func accountSummaryOnward() {
        store.dispatch(action: WvActions.OnPage(page: .transferOccuring)) //stops refreshes from occuring.
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
            self.transferOnward()  //MARK: should be called via context.swift -> action
        }.catch { _ in
           self.showWebView()
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
            if store.state.cartPayClicked {
                self.sendPageOnwardCommerce() //MARK: MERCHANT
            }
            else {
                self.sendPageOnwardPeer() //MARK: PEER
            }
        }.catch { _ in
           self.showWebView()
        }
        
    }
    func sendPageOnwardPeer() {
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
        }.catch { _ in
           self.showWebView()
        }
    }
    
    func sendPageOnwardCommerce() {
        let page = store.state.page!
        let amount = String(store.state.amountToSend)
        var name: String = store.state.recipName ?? "Anon"
        let email: String =  store.state.recipEmail!
        let cart: Cart =  store.state.cart!
        let shipping: String = store.state.shippingAddr ?? "No shipping address provided. We reccomend the customer email: \(email) with their sessionId if required."
        
        if name.isEmpty {
            name = "Merchant"
        }
        
//        let jsonCart: String = MHelpers.cartToJson(cart: cart)
//        let jsonCartProducts: String = MHelpers.cartToJsonCartProducts(cart: cart)
//        print("json cart: ", jsonCart)
//        print("json cart products: ", jsonCartProducts)
        let jC = MHelpers.cartProdString(cart: cart)

        print("hello")
        print("jC", jC)
       
        let multiLine = " \(jC) \\n Shipping addr: \(shipping)"
        let multiLine2 = "\\n\(jC) \\nShipping address:\\n\(shipping)"
        print("cart + shipping char length:", multiLine2.count)
       // jC + =
        
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
        }
            .then {
                page.evaluate("msgEl = document.querySelector(\"#eMemo\");")
            }.then {
                page.evaluate("msgEl.innerText = 'New intr order - sessionId: \(cart.sessionId!) \\n\(multiLine2)';") //MARK: \n does not work. only \\n
            }   //MARK:FOR TESTING, DON'T CLICK CONFIRM SUMBIT - UNCOMMENT WHEN WANT TO SEND REAL
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                store.dispatch(action: WvActions.BackToAcctSumm())
            }
           // store.dispatch(action: AppActions.ScreenshotSaved(image: image, fileName: fullFileName)) this action is dispatched in saveImg function
        }
    }

}


