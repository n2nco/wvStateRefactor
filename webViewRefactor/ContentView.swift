//
//  ContentView.swift
//  webViewRefactor
//
//  Created by Blake  on 2020-03-14.
//  Copyright © 2020 b. All rights reserved.
//

import SwiftUI
import SwiftUIFlux

struct ContentView: View {
    @EnvironmentObject var store : Store<AppState>
    
    var body: some View {
        return VStack{
            
   
            Text("tap to simulate merchant pay") .onTapGesture {
                self.store.dispatch(action: AppActions.CartPayClicked())
                self.store.dispatch(action: AppActions.SetCart(cart: MHelpers.jsonDecodeToCart()!))
                self.store.dispatch(action: WvActions.InitPay())

               }
          //  if (store.state.sceneState == .showingWebView) {
                WebView()
           //! }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
