//
//  OpenInSafariActivity.swift
//  iBurn
//
//  Created by iBurn Development Team on 8/8/25.
//  Copyright © 2025 iBurn. All rights reserved.
//

import UIKit
import SafariServices

class OpenInSafariActivity: UIActivity {
    
    private var url: URL?
    
    override var activityType: UIActivity.ActivityType? {
        return UIActivity.ActivityType("com.iburnapp.openInSafari")
    }
    
    override var activityTitle: String? {
        return "Open in Safari"
    }
    
    override var activityImage: UIImage? {
        return UIImage(systemName: "safari")
    }
    
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        for item in activityItems {
            if let url = item as? URL, UIApplication.shared.canOpenURL(url) {
                return true
            }
        }
        return false
    }
    
    override func prepare(withActivityItems activityItems: [Any]) {
        for item in activityItems {
            if let url = item as? URL {
                self.url = url
                return
            }
        }
    }
    
    override func perform() {
        guard let url = url else {
            activityDidFinish(false)
            return
        }
        
        UIApplication.shared.open(url) { success in
            DispatchQueue.main.async {
                self.activityDidFinish(success)
            }
        }
    }
}