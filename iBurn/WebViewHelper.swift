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
}
