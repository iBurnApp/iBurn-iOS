//
//  ColorCache.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/7/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import Foundation
import UIImageColors

extension UIImageColors {
    var brc_ImageColors: BRCImageColors {
        let colors = BRCImageColors(backgroundColor: background, primaryColor: primary, secondaryColor: secondary, detailColor: detail)
        return colors
    }
}

public protocol ColorTheme {
    func setColorTheme(_ colors: BRCImageColors, animated: Bool)
}

extension UINavigationBar: ColorTheme {
    public func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        let theme = {
            self.barTintColor = colors.backgroundColor
            self.tintColor = colors.secondaryColor
            self.titleTextAttributes = [NSForegroundColorAttributeName: colors.primaryColor]
        }
        if animated {
            UIView.transition(with: self, duration: 0.25, options: [.beginFromCurrentState, .transitionCrossDissolve], animations: theme, completion: nil)
        } else {
            theme()
        }
    }
}

extension UITableView: ColorTheme {
    public func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        self.backgroundColor = colors.backgroundColor
        self.tintColor = colors.primaryColor
    }
}

extension UIViewController: ColorTheme {
    public func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        view.backgroundColor = colors.backgroundColor
        view.tintColor = colors.primaryColor
    }
    
    /** 
     * This is for the BRCDetailViewController so the navbar
     * information gets propagated to the UIPageViewController
     */
    public func copyParameters(from fromVC: UIViewController) {
        let destination = self
        let source = fromVC

        // https://stackoverflow.com/a/35820522/805882
        let fadeTextAnimation = CATransition()
        fadeTextAnimation.duration = 0.25
        fadeTextAnimation.type = kCATransitionFade
        navigationController?.navigationBar.layer.add(fadeTextAnimation, forKey: "fadeText")
        
        destination.title = source.title
        destination.navigationItem.rightBarButtonItem = source.navigationItem.rightBarButtonItem
    }
}

public extension UIPageViewController {
    /** Copy the paramters from top child view controller */
    public func copyChildParameters() {
        guard let top = self.viewControllers?.first else { return }
        copyParameters(from: top)
    }
}



public class ColorCache {
    static let shared = ColorCache()
    let readConnection = BRCDatabaseManager.shared.readConnection
    let writeConnection = BRCDatabaseManager.shared.readWriteConnection
    var completionQueue = DispatchQueue.main
    
    /** Only works for art objects at the moment */
    func getColors(art: BRCArtObject, artMetadata: BRCArtMetadata, image: UIImage, downscaleSize: CGSize, completion: @escaping (BRCImageColors)->Void) {
        // Found colors in cache
        if let colors = artMetadata.thumbnailImageColors {
            self.completionQueue.async {
                completion(colors)
            }
            return
        }
        DispatchQueue.global(qos: .userInteractive).async {
            // Maybe find colors in database when given stale artMetadata
            var existingColors: BRCImageColors? = nil
            self.readConnection.read { transaction in
                let artMetadata = art.artMetadata(with: transaction)
                existingColors = artMetadata.thumbnailImageColors
            }
            if let colors = existingColors {
                self.completionQueue.async {
                    completion(colors)
                }
                return
            }
            
            // Otherwise calculate the colors and save to db
            let colors = image.getColors(scaleDownSize: downscaleSize)
            let brcColors = colors.brc_ImageColors
            self.completionQueue.async {
                completion(brcColors)
            }
            self.writeConnection.asyncReadWrite { transaction in
                let metadata = art.artMetadata(with: transaction).metadataCopy()
                metadata.thumbnailImageColors = brcColors
                art.replace(metadata, transaction: transaction)
            }
        }
    }
}
