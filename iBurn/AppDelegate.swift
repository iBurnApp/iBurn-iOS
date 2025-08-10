//
//  AppDelegate.swift
//  iBurn
//
//  Created by Chris Ballinger on 4/12/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation
import Siren

// Use Swift entry point for better debugging in Xcode 9.1+
@main
final class AppDelegate: BRCAppDelegate {
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        Siren.shared.wail()
        
        // Preload common emojis for better map performance
        DispatchQueue.global(qos: .background).async {
            EmojiImageRenderer.shared.preloadCommonEmojis()
        }
        
        return result
    }
}
