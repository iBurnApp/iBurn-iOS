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

@objc public protocol ColorTheme {
    func setColorTheme(_ colors: BRCImageColors, animated: Bool)
}

extension UINavigationBar: ColorTheme {
    @objc public func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        let theme = {
            self.barTintColor = colors.backgroundColor
            self.tintColor = colors.secondaryColor
            self.titleTextAttributes = [NSAttributedStringKey.foregroundColor: colors.primaryColor]
        }
        if animated {
            UIView.transition(with: self, duration: 0.25, options: [.beginFromCurrentState, .transitionCrossDissolve], animations: theme, completion: nil)
        } else {
            theme()
        }
    }
}

extension UITableView: ColorTheme {
    @objc public func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        self.backgroundColor = colors.backgroundColor
        self.tintColor = colors.primaryColor
    }
}

extension UIViewController: ColorTheme {
    @objc public func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        view.backgroundColor = colors.backgroundColor
        view.tintColor = colors.primaryColor
    }
    
    /** 
     * This is for the BRCDetailViewController so the navbar
     * information gets propagated to the UIPageViewController
     */
    @objc public func copyParameters(from fromVC: UIViewController) {
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
    @objc public func copyChildParameters() {
        guard let top = self.viewControllers?.first else { return }
        copyParameters(from: top)
    }
}



public class ColorCache: NSObject {
    @objc static let shared = ColorCache()
    let backgroundReadConnection = BRCDatabaseManager.shared.backgroundReadConnection
    let writeConnection = BRCDatabaseManager.shared.readWriteConnection
    var completionQueue = DispatchQueue.main
    
    @objc func prefetchAllColors() {
        DispatchQueue.global(qos: .default).async {
            var objects: [(BRCArtObject, BRCArtMetadata)] = []
            self.backgroundReadConnection.read { transaction in
                transaction.enumerateRows(inCollection: BRCArtObject.yapCollection, using: { (key, object, metadata, stop) in
                    guard let art = object as? BRCArtObject else {
                        return
                    }
                    let artMetadata = art.artMetadata(with: transaction)
                    if artMetadata.thumbnailImageColors != nil {
                        return
                    }
                    if art.localThumbnailURL != nil {
                        objects.append((art, artMetadata))
                    }
                })
            }
            objects.forEach({ (art, metadata) in
                guard let image = BRCMediaDownloader.imageForArt(art) else {
                    return
                }
                self.getColors(art: art, artMetadata: metadata, image: image, downscaleSize: .zero, processingQueue: nil, completion: nil)
            })
        }
    }
    
    /** Only works for art objects at the moment. If processingQueue is nil, it will execute block on current queue */
    func getColors(art: BRCArtObject, artMetadata: BRCArtMetadata, image: UIImage, downscaleSize: CGSize, processingQueue: DispatchQueue?, completion: ((BRCImageColors)->Void)?) {
        // Found colors in cache
        if let colors = artMetadata.thumbnailImageColors {
            if let completion = completion {
                self.completionQueue.async {
                    completion(colors)
                }
            }
            return
        }
        let processBlock = {
            // Maybe find colors in database when given stale artMetadata
            var existingColors: BRCImageColors? = nil
            self.backgroundReadConnection.read { transaction in
                let artMetadata = art.artMetadata(with: transaction)
                existingColors = artMetadata.thumbnailImageColors
            }
            if let colors = existingColors {
                if let completion = completion {
                    self.completionQueue.async {
                        completion(colors)
                    }
                }
                return
            }
            
            // Otherwise calculate the colors and save to db
            let colors = image.getColors(quality: .high)
            let brcColors = colors.brc_ImageColors
            if let completion = completion {
                self.completionQueue.async {
                    completion(brcColors)
                }
            }
            
            self.writeConnection.asyncReadWrite { transaction in
                let metadata = art.artMetadata(with: transaction).metadataCopy()
                metadata.thumbnailImageColors = brcColors
                art.replace(metadata, transaction: transaction)
            }
        }
        if let processingQueue = processingQueue {
            processingQueue.async {
                processBlock()
            }
        } else {
            processBlock()
        }
    }
}
