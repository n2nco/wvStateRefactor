//
//  helpers.swift
//  swiftRedux
//
//  Created by Blake  on 2020-03-09.
//  Copyright © 2020 b. All rights reserved.
//

import Foundation
import LocalAuthentication
import AVFoundation
import SwiftUI


var audioPlayer: AVAudioPlayer?
func playSound(sound: String, type: String) {
    if let path = Bundle.main.path(forResource: sound, ofType: type) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            audioPlayer?.play()
        } catch {
            print("could not find & play sound file")
        }
    }
}



func authenticate() -> String {
    let context = LAContext()
    var error: NSError?
    
    context.localizedCancelTitle = "Enter"
    
    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
        let reason = "Please authenticate yourself to unlock your account."
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
            
            DispatchQueue.main.async {
                if success {
                    store.dispatch(action: AppActions.AuthSuccess())
                } else {
                    print("auth failed")
                }
            }
        }
    } else {
     
        print("no biometrics available")
        return "no biometrics available"
    }
    return "success"
}

func saveImage(image: UIImage, fileName: String) -> Bool{
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let path = paths[0]
    
    guard let data = image.pngData() else {
        return false
    }
//    guard let directory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) as NSURL else {
//        return false
//    }
    let filePath = path.appendingPathComponent("fileName.png")
    

    do{
        try? data.write(to: filePath)
        
        print("saved to: ", filePath)
        
        store.dispatch(action: AppActions.ScreenshotSaved(image: image, imageData: data, fileName: filePath.absoluteString, fileURL: filePath ))
        return true
    } catch {
        print(error.localizedDescription)
        return false
    }
}


