//
//  WebViewHelper.swift
//  iBurn
//
//  Created by Chris Ballinger on 6/2/19.
//  Copyright © 2019 Burning Man Earth. All rights reserved.
//

import Foundation
import SafariServices

@objc
public class WebViewHelper: NSObject {
    @objc public static func presentWebView(url: URL, from viewController: UIViewController) {
        guard url.scheme?.contains("http") == true else {
            print("cannot present non-http(s) URLs: url")
            return
        }
        let safariVC = SFSafariViewController(url: url)
        viewController.present(safariVC, animated: true, completion: nil)
    }
    
    @objc public static func openEmail(to email: String) {
        guard let emailURL = URL(string: "mailto:\(email)") else {
            print("Invalid email address: \(email)")
            return
        }
        
        guard UIApplication.shared.canOpenURL(emailURL) else {
            print("Cannot open email client")
            return
        }
        
        UIApplication.shared.open(emailURL)
    }
}
