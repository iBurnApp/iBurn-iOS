//
//  Storyboard.swift
//  iBurn
//
//  Created by Chris Ballinger on 7/30/18.
//  Copyright © 2018 Burning Man Earth. All rights reserved.
//

import Foundation

@objc public class Storyboard: NSObject {
    @objc public static let more = UIStoryboard(name: "More", bundle: Bundle(for: Storyboard.self))
}

@objc public protocol StoryboardRepresentable: NSObjectProtocol {
    static func fromStoryboard() -> UIViewController
}
