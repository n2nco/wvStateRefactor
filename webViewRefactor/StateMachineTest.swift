//
//  StateMachineTest.swift
//  webViewRefactor
//
//  Created by Blake  on 2020-03-17.
//  Copyright © 2020 b. All rights reserved.
//

//import Foundation
////
//
//import Foundation
//import SwiftUIFlux
//import PromiseKit
//import stateful
//
//
//
//
//struct WvState: FluxState  {
//    var wvNav = WvNav() // ensure wvNav is created after appstate's page is set.
//    
//    public enum Bank: String  {
//        case rbc, td
//    }
//    public enum Page: String  {
//           case none, login, secQuestion, accountSummary, complete
//       }
//     public enum WvAction: String  {
//         case showWv, attemptLogin, checkBalance, eTransfer, complete
//     }
//    
//    class StateMachineExamples {
//        let parent : WvState
//        typealias TransitionDefault = Transition<Page, WvAction>
//        typealias StateMachineDefault = StateMachine<Page, WvAction>
//        init(_ parent: WvState) {
//            self.parent = parent
//        }
//
//     func runSampleStateMachine() {
//        let stateMachine = StateMachineDefault(initialState: .none)
//            let t1 = TransitionDefault(with: .attemptLogin,
//                                              from: .none,
//                                              to: .login,
//                                              preBlock: {
//                                                print("Going to move from \(Page.none) to \(Page.login)!")
//                                                self.parent.wvNav.attemptRLogin()
//                   }, postBlock: {
//                    print("Just moved from \(Page.none) to \(Page.login)!")
//                   })
//            
//            stateMachine.add(transition: t1)
//            let loginCallback: TransitionBlock = { result in
//                      switch result {
//                          case .success:
//                              print("Event login sucess")
//                          case .failure:
//                              print("Event login cannot currently be processed.")
//                          }
//                      }
//        stateMachine.process(event: .attemptLogin, callback: loginCallback)
//        }
//    }
//    
//    
//    
//    
//    
//    
//    //New User:
//    //AppState.Bank -> create Page -> attemptLogigin.fail -> Peer vs. Merchant -> showWv to get creds -> page.accountSummary - eTransfer.
//    
//    //Existing user:
//    //AppState.Bank -> createPage -> attemptLogin.success (fail = merge into flow above) -> Peer vs. Merchant on click -> eTransfer
//
//   
//    //All: on error (insufficient balance): showWv, then pick up where left off.
//    //All: option to 'cancel' and reset to blank state.
//    
// 
//    
//    //Page
//    //Assume appstate.bank = .rbc for now. can add additional switch later.
//    var page: Page = .none {
//          willSet {
//            switch newValue {
//            case .none:
//                StateMachineExamples(self).runSampleStateMachine() //MARK: testing state machine
//               // wvNav.attemptRLogin()
//            case .login:
//                print("on login page")
//            case .secQuestion:
//                print("login")
//            case .accountSummary:
//               print("accountsummary wvstate")
//                wvNav.setToRefresh()
//               // wvNav.attemptRLogin() //MARK: This works to take you back to the account summary page & await.
//                wvNav.getToEtransferPage()
//
//            case .complete:
//                print("complete")
//       
//            }
//        }
//    }
//    init() {
//        
//    }
//}
//
////Make new Page logic based on WvState and AppState.
////Then the new page value on set pushes the process forward.
//func wvStateReducer(state: WvState, action: Action) -> WvState {
//    var state = state
//    
//    switch action {
//    case let action as WvActions.OnPage:
//        state.page = action.page
//    default:
//          break
//      }
//      return state
//}
//
//struct WvActions {
//    struct OnPage:Action {
//        let page: WvState.Page
//    }
//}
//
////can extend this class to include all the navlib functions. just don't ensure page is a singleton.
//
//class WvNav {
//    //MARK: reference all state through main store only?
//    var page: MarionetteLite? = gpage //ensure always referencing store page.
//    //var wvState: WvState? = store.state.wvState //
//   
//    init() { //MarionetteLite = class. so ref type.
//     //   self.WvState = wvState // would this assignment create a copy that would f things up?
//        
//    }
//    @objc func refresh() {
//        if store.state.wvState.page == .accountSummary {
//            page?.evaluate("location.reload()") //works
//        }
//            
//    }
//    func setToRefresh() {
//        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(refresh), userInfo: nil, repeats: true) // refresh every 30 sec
//    }
//}
//
//extension WvNav {
//    func attemptRLogin() {
//        var u:String = "******"
//        var p:String = "*****"
//                firstly {
//                     store.state.page!.goto(URL(string: "https://www1.royalbank.com/cgi-bin/rbaccess/rbcgi3m01?F6=1&F7=IB&F21=IB&F22=IB&REQUEST=ClientSignin&LANGUAGE=ENGLISH&_ga=2.142611827.717899448.1581641814-1982597706.1581288543")!)
//                     //NOTE: goto subsribes to wait for navigation.
//                 }.then { data -> Promise<String> in
//                     // something that should only happen if xyz is not nil
//                     store.state.page!.quickEvaluate("document.querySelector(\"#K1\").value = '\(u ?? "")';")
//                 }.then { data -> Promise<String> in
//                    store.state.page!.quickEvaluate("document.querySelector(\"#Q1\").value = '\(p ?? "")';")
//                 }
//                 //.then { data -> Promise<Void> in
//                 .done {  ready in
//                     store.state.page!.quickEvaluate("document.querySelector(\".yellowBtnLarge\").click();")
//                 }
//            }
//        
//    //goes from acct summ to etransfer. works. but can't sit and refresh on this page.
//    func getToEtransferPage() {
//         //can move this to action.
//        let page = store.state.page!
//        
//        
//        firstly {
//            page.evaluate("document.querySelector(\"a[ga-event-label='Send an Interac eTransfer']\").click();")
//        }
//        
//        .then {
//            page.waitForNavigation()
//        }.done { ready in
//             
//        }
//        
//    }
//
//}
