//
//  WebViewSheetView.swift
//  swiftRedux
//
//  Created by Blake  on 2020-03-11.
//  Copyright © 2020 b. All rights reserved.
//

import Foundation
import SwiftUI
import SwiftUIFlux



struct WVSheet: View {
    @EnvironmentObject var store : Store<AppState>
    
    //@State var credsAlertShown: Bool = false //ensure only shown once.
    
   // @State var showCA: Bool = true
  @State var alertShown: Bool = false
    var body: some View {
        //custom binding. ref: https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-custom-bindings
        //this is like a local-to-view computed property. and it's computed based on the store.state. (can't do this with @state).
        let showCredsAlert = Binding(
            get: { () -> Bool in
                print("store credentials set:", self.store.state.userState.credentialsSet)
                //MARK: determines whether to show alert.
                if (!self.store.state.userState.credentialsSet && self.alertShown == false) {
                    DispatchQueue.main.async {
                        self.alertShown = true //don't place at top of call stack. why? don't want this struct to re-render immediately on state change & not render alert (not sure of underlying swift here, playing it safe)
                    }
                    return true // only time to show creds alert!
                }
                return false
            },
            set: {
                //setter is required to implement. $0 = 1st arg = value being set (i belive)
                if $0 == false {
                   false
                }
                if $0 == true {
                    true
                    
                }
            }
       )
        return ScrollView {
            VStack {
//                Image(uiImage: UIImage(named: "logo_transparent_cropped")!)
//                    .resizable()
//                    .aspectRatio(contentMode: .fit)
//                    // .frame(alignment: .top)
//                    .padding(.top, 50)
//                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: 100, alignment: .center)
//                    .edgesIgnoringSafeArea(.all)
                Text("your payment to \(self.store.state.recipName ?? " " )").font(.custom("Helvetica Neue", size: 20)).foregroundColor(.white)
//                Spacer().frame(height: 10)
                Text("sending \(self.store.state.recipEmail ?? "") $\(String(self.store.state.amountToSend) )").font(.custom("HelveticaNeue-Thin", size: 14)).foregroundColor(.white)
//                Spacer().frame(height: 20)
//                if !self.store.state.userState.credentialsSet {
//                    //                    Alert(title: Text("1st time user"), message: Text("credentials not yet set. login to proceed. you will not be prompted to login in subsequent transactions.").font(.custom("HelveticaNeue-Thin", size: 16)).foregroundColor(.white))
//                    Text("you will not have to login for subsequent transactions").font(.custom("HelveticaNeue-Thin", size: 12)).foregroundColor(.white).frame(alignment: .center)
//                    Spacer().frame(height: 18)
//                }
//                //MARK: determines whether to show non-alert 'invalid creds on file'
//
//                if !(self.store.state.userState.credsValid ?? true) { //if not set (never sent tx), don't render this. if user w/ prev tx send is using and was set to at some point false, render this.
//                    Text("invalid credentials on file").font(.custom("HelveticaNeue-Thin", size: 16)).foregroundColor(.white).frame(alignment: .center).frame(alignment: .center)
//                    Spacer().frame(height: 18)
//                }
//                WebView().environmentObject(self.store)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 10)
//                            .stroke(Color(red: 0.85 , green: 0.85 , blue: 0.85 ), lineWidth: 2)
//                            .shadow(color: Color.black, radius: 10)
//
//                ).frame(minHeight: 500)
//                    .padding(.bottom, 30)
//            }
//                //using custom binding, so no indirect ref to source of truth, so doesn't require $showC..
//                .alert(isPresented: showCredsAlert) {
//                   return Alert(title: Text("1st time user login"), message: Text("credentials not yet set.\n login to proceed."), dismissButton: .default(Text("Got it!")))
//            }.background(LinearGradient(Color.darkStart, Color.darkEnd)).frame(minWidth: 0, maxWidth: .infinity).cornerRadius(10)
//
            
        } 
    }
}
}

//not in use:
//var alertRemoveCalled = false
//func removeAlert() {
//    if !alertRemoveCalled {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { //trial to autodismiss this alert if not clicked.
//            store.dispatch(action: AppActions.CredsNotSet(nowSet: true))
//        }
//    }
//    alertRemoveCalled = true
//}

