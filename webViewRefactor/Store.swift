//
//  Store.swift
//  swiftRedux
//
//  Created by b on 2020-03-08.
//  Copyright © 2020 b. All rights reserved.
//

import Foundation
import SwiftUIFlux
import SwiftUI

//MARK: APP
//MARK: usage: @EnvironmentObject private var store: Store<AppState>. https://github.com/Dimillian/MovieSwiftUI/blob/52e852fc3da2524fd784374727e747eaba8497b6/MovieSwift/Shared/flux/state/AppState.swift#L18

//MARk: gpage

var pageCreated = 0
var gpage: MarionetteLite? = createPageOnce()
var createPageOnce: () -> MarionetteLite? = {
   return MarionetteLite()
  // return p
}

struct AppState: FluxState {
    
    var initWebViewCalled = false // want to ensure only creating webview once.
    
    var userState: UserState //usage => store.state.userstate
    var wvState: WvState
    
    
    public enum Scenes {
        case landingPage, mainPage, showingQrData, showingWebView, sending, showingScreenshot, confirmed
    }
    var sceneState = Scenes.landingPage //set to begin on landing page (can change to mainPage).
    
    var noBiometrics = false
    var authenticated: Bool = false //TouchID
    
    //MARK: important vars (will run validation on)
    var amountToSend: Double = 0.00  {
        willSet {
            print("willset amountToSend", newValue)
        }
        didSet {
            print("didset amount to send. Old value:", oldValue)
            print("didset amount to send. new value:", amountToSend)
        }
    }
    var recipName: String?
    var recipEmail: String?
    var amountFromButton: Bool = false //ensures input reflects button selected-values.
    var emailFromButton: Bool =  false
    
    
    var shippingAddr: String? 
    
    var qrRead: Bool = false
    
    var cart: Cart?
    //to add: app-verified url:email
    
    var payClicked: Bool = false //PEER
    var cartPayClicked: Bool = false //COMMERCE
  
    
    var credsNotSet: Bool = false //assume creds are set. alert if true
  //  var needToGetCreds: Bool = false
    
    enum Bank {
        case rbc, td
    }
    var usingBank: Bank?
    
    var transferInProgress = false
    
    //best way to make page into singleton? i.e. make it a global var? create it in a dispatch_once?
    
    var page = gpage //ref to MarionetteLite instance. //page is like a browser tab (puppeteer lingo).

    
    var accountSummaryOnwardCalled = false
    var onAccountSummary: Bool = false {
        didSet {
            if !accountSummaryOnwardCalled {
                //accountSummaryOnward() called by action now.
                accountSummaryOnwardCalled = true //ensure only called once. don't want multiple tx :).
            }
           
            saveUserState() //save alread-set userstate credentials to persistent storage, as this was a successful login.
        }
    }
    
    var sufficientBalance: Bool?
    var inProgress: Bool = false
    var transferError: Bool = false {
        didSet {
            store.dispatch(action: AppActions.ChangeScene(newScene: .showingWebView))//let user handle this in webview?
        }
    }
    var complete: Bool = false {
        didSet {
            print("appstate's complete value changed")
            recipEmail = ""
            recipName = ""
            amountToSend = 0
           // saveUserState()
            //need a 'reset state' function (incluing creatign a new MarionetteLite page & calling initWebview)
        }
    }
    var screenShotSaved: Bool = false
    var screenShot: UIImage?
    var screenShotData: Data? 
    
    var screenShotFileName: String?
    var screenShotURL : URL?
    
    init() {
        let savedUserState: Data? = KeychainWrapper.standard.data(forKey: "UserState")
    
        if savedUserState != nil {
            do {
                let decodedUserState = try JSONDecoder().decode(UserState.self, from: savedUserState!)
                self.userState = decodedUserState //use saved userstate.
                print("using saved userState")
               }
            catch  {
                print("error decoding non nil retreived userState", error.localizedDescription)
                self.userState = UserState()
            }
        }
       
        else {
            self.userState = UserState() //1st time user.
        }
        self.wvState = WvState() //Call once only.
    }
}
//appStateReducer holds all substate reducers. AppState holds all __State structs. (i.e. App__ holds User__).
//This combined reducer is used to create 'store', which is the important store/state reference.
func appStateReducer(state: AppState, action: Action) -> AppState {
    var state = state
    
    switch action {
        
    case let action as AppActions.ChangeScene:
        state.sceneState = action.newScene
    
    case let action as AppActions.InitWebView:
        if state.page == nil {
            print("creating page in initWebview action")
            state.page = MarionetteLite()
        }
        state.initWebViewCalled = true
        //ensure this is only ever called once?
    case let action as AppActions.AttemptRbcLogin:
         attemptRbcLogin() // MARK: background login attempt begins.
    case let action as AppActions.CredsNotSet:
        if action.nowSet == true {
            state.credsNotSet = false
        }
        state.credsNotSet = true //default. triggers alert that creds need to be set in WVSheet.
        
        
    case let action as AppActions.SetAmount:
        //background login attempt webview setup.
        print("in SetAmount action.")
        let twoDecPlaces: String = String(format: "%.2f", action.amountToSend)
        let dTwoDecPlaces: Double = Double(twoDecPlaces)!
        
        state.amountToSend = dTwoDecPlaces //doesn't work lol
//        let numberFormatter = NumberFormatter()
//        numberFormatter.minimumFractionDigits = 2
//        let newDoub : Double = numberFormatter.double(dTwoDecPlaces)
//        state.amountToSend = newDoub
        state.amountFromButton = action.amountFromButton ?? false
        
    case let action as AppActions.SetRecipEmail:
        state.recipEmail = action.recipEmail
        state.emailFromButton = action.emailFromButton ?? false
    case let action as AppActions.SetCart: //On QR scan checkout.
        state.cart = action.cart /// change scene to presentCart here or elsewhere?
        
        //state.recipName = action.cart.merchantName - add merchant name later?
        state.recipEmail = action.cart.merchantEmail //can add site/merchant name
        state.amountToSend = action.cart.cartTotal
        
        state.qrRead = true //bound to in contentview.
        state.sceneState = .showingQrData
        
        
    case let action as AppActions.PayClicked:
        state.payClicked = true
        
    case let action as AppActions.CartPayClicked:
        state.cartPayClicked = true
       
    case let action as AppActions.Authenticate:
        let x = authenticate()
        if x == "no biometrics available" {
            state.noBiometrics = true //not in use right now. unsure how to subscribe to when they enroll in biometrics.
        }
        //MARK: Auth success always inits a transfer (checkout or p2p click).
        //MARK: Once auth success, you're either on acct summary or not.
        //MARK: You only want on account summary to propagate tx if a) authed b) checkout | p2p clicked.
    case let action as AppActions.AuthSuccess:
        state.authenticated = true
        initTransfer()
    case let action as AppActions.OnAccountSummary:
        print("rbc login success. conditional wait or proceed immediately.")
        state.onAccountSummary = true // triggers userState save to keychain (persistent) + calls next navlib
        if state.authenticated == true && (state.cartPayClicked || state.payClicked) {
        initTransfer() // calls above action.
        }
    //when to state.showQrReading = false?
    
    case let action as AppActions.InitRBCTransfer:
        state.usingBank = .rbc //not in use.
        //state.transferInProgress = true
        if !state.onAccountSummary{
            state.sceneState = .showingWebView //must get creds.
//            state.needToGetCreds = true //ensure this sets before attemptRbcLogin
            attemptRbcLogin(needToGetCreds: true) //can attempt login with blank creds anyway. can change this into separate func later
            break
        }
        state.sceneState = .sending //
        accountSummaryOnward()

        
    case let action as AppActions.HideWebView:
         state.sceneState = .mainPage  //non-ChangeScene approach. delete if not used.

    case let action as AppActions.TransferError:
        state.transferError = true
    case let action as AppActions.TransferComplete:
        state.complete = true // also triggers userState save to keychain (persistent).
    case let action as AppActions.ScreenshotSaved:
        
        state.screenShot = action.image
        state.screenShotData = action.imageData
        state.screenShotFileName = action.fileName
        state.screenShotURL = action.fileURL
        
        state.screenShotSaved = true
        
        txCompleteActions() //this changes scene to .showingScreenshot
     case let action as AppActions.ResetAppState:
        //MARK: TODO - Reset - a) manually set values b) create a new appstate.
        break
      
        
    default:
        break
    }
    
    
    state.userState = userStateReducer(state: state.userState, action: action)
    state.wvState = wvStateReducer(state: state.wvState, action: action)
    return state
}


///Actions. ensure to declare any action.varNames you intend to pass in & use in reducer here.
struct AppActions {
    struct Toggle:Action {
        
    }
    struct Display:Action {
        let textToDisplay: String
    }
    struct ChangeScene:Action {
        let newScene: AppState.Scenes
    }
    struct AttemptRbcLogin:Action {
        
    }
    struct Authenticate:Action {
        
    }
    struct AuthSuccess:Action {
        
    }
    struct CredsNotSet: Action {
        let nowSet: Bool?
    }
    struct InitRBCTransfer: Action {
        
    }
    struct SetAmount: Action {
        let amountToSend: Double
        let amountFromButton: Bool
        
    }
    struct SetRecipEmail: Action {
        let recipEmail: String
        let emailFromButton: Bool
        
    }
    struct SetCart: Action {
        let cart: Cart//model.swift struct. contains cartItem array.
    }
    struct PayClicked: Action {
           
    }
    struct CartPayClicked: Action {
        
    }
   
    struct InitWebView: Action {
        
    }
//    struct ShowWebView: Action {
//        
//    }
    struct HideWebView: Action {
        
    }
    
    struct OnAccountSummary:Action {
        
    }
    struct TransferError:Action {
        
    }
    struct TransferComplete:Action {
        
    }
    struct ScreenshotSaved:Action {
        let image : UIImage
        let imageData: Data
        let fileName: String
        let fileURL: URL
           
    }
    struct ResetAppState:Action {
        
    }
}

//MARK: USER
//Make userstate 'codable' and pull from keychain with each use?
//MARK: purpose of UserState: structure persisent user state here for serialization+persistentStorage + pull in for initialization of app.
struct UserState: FluxState, Codable {
    var displayName: Bool = false
    var name: String = "joe"
    var userName: String?
    
    //using below computed property to determine whether to fire AppActions.CredsNotSet
    var credentialsSet: Bool {
        print("printing username from credsSet computed prop", rbcUsername)
        if (rbcUsername != nil && rbcUsername != "" && rbcPassword != nil && rbcPassword != "") {
            
            return true
        }
        return false
    }
    var credsValid: Bool?
    var rbcUsername : String?
    var rbcPassword : String?

    var SecurityQuestions: [String]?
    var SecQAnswer : String?
}


struct UserActions {
    struct DisplayName:Action {
        
    }
    struct SetName:Action {
        let name:String
    }
    struct CredsNotSet: Action {
        
    }
    struct SetUsername:Action {
        let rbcUsername : String
    }
    struct SetPassword:Action{
        let rbcPassword: String
    }
    struct CredsValid: Action {
        let valid: Bool
    }
    
    struct RecordAmount:Action{ //For record of past tx, can construct, dispatch, and store an array of PastTransfer structs instead.
        let amountToSend: Double
    }
    struct RecordRecipient:Action{
        let recipient: String
    }
    struct SaveTransfer:Action {
        
    }
    struct SaveUserState:Action {
        
    }
    
}

func userStateReducer(state: UserState, action: Action) -> UserState {
    var state = state  // state here is UserState
    
    switch action {
    case let action as UserActions.DisplayName:
        state.displayName = true
    case let action as UserActions.SetName:
        state.name = action.name
    case let action as UserActions.SetUsername:
        print("new username being set")
        state.rbcUsername = action.rbcUsername
    case let action as UserActions.SetPassword:
        state.rbcPassword = action.rbcPassword
    //state.buttonPressed = !state.buttonPressed
    case let action as UserActions.CredsValid:
        if action.valid == true {
                   state.credsValid = true
               }
             else {
                 state.credsValid = false  //default.
             }
    case let action as UserActions.SaveTransfer:
        print("will save transfer data for history")
    
    //to do
    case let action as UserActions.SaveUserState:
        let data: Data = try! JSONEncoder().encode(state)
        let userSaveSuccessful: Bool = KeychainWrapper.standard.set(data, forKey: "UserState")
        
    default:
        break
    }
    return state
}




let store = Store<AppState> (reducer: appStateReducer, state: AppState())

//used when account summary is hit (among other future cases i.e. choosing bank, tx completed etc.)
func saveUserState() {
    store.dispatch(action: UserActions.SaveUserState())
}

func initTransfer() {
    store.dispatch(action: AppActions.InitRBCTransfer())
}

func txCompleteActions() {
    store.dispatch(action: AppActions.TransferComplete())
    store.dispatch(action: AppActions.ChangeScene(newScene: .showingScreenshot))
}

//Fundamental mental model:
//we have a store that's a reducer connected to state.
//every component imports the store via @EnvionrmentObject store

//we use store throughout app via:
//we pull store.state
//we push store.dispatch(action: ActionType) -> the reducer is the only function where you are allowed to mutate your state.
//new state struct is returned


//Aside: make an action of type : AsyncAction if doing external api calls.







//func moviesStateReducer(state: MoviesState, action: Action) -> MoviesState {
//    var state = state
//    switch action {
//    case let action as MoviesActions.SetMovie:
//        state.movies[action.id] = action.movie
//
//    default:
//        break
//    }
//
//    return state
//}
