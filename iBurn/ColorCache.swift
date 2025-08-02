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

extension UIViewController {
    func refreshNavigationBarColors(_ animated: Bool) {
        self.navigationController?.navigationBar.setColorTheme(Appearance.currentColors, animated: animated)
    }
}

@objc public protocol ColorTheme {
    func setColorTheme(_ colors: BRCImageColors, animated: Bool)
}

extension UINavigationBar: ColorTheme {
    @objc public func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        self.titleTextAttributes = [.foregroundColor: colors.secondaryColor]
        let theme = {
            self.barTintColor = colors.backgroundColor
            self.tintColor = colors.primaryColor
        }
        if animated {
            UIView.transition(with: self, duration: 0.25, options: [.beginFromCurrentState, .transitionCrossDissolve], animations: theme, completion: nil)
        } else {
            theme()
        }
    }
}

extension UITabBar {
    @objc public func setColorTheme(_ colors: BRCImageColors, animated: Bool) {
        backgroundColor = colors.backgroundColor
        tintColor = colors.primaryColor
        barTintColor = colors.backgroundColor
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
        fadeTextAnimation.type = CATransitionType.fade
        navigationController?.navigationBar.layer.add(fadeTextAnimation, forKey: "fadeText")
        
        destination.title = source.title
        if let rightBarButtonItems = source.navigationItem.rightBarButtonItems {
            destination.navigationItem.rightBarButtonItems = rightBarButtonItems
        } else {
            destination.navigationItem.trailingItemGroups = source.navigationItem.trailingItemGroups
        }
    }
}

extension UIPageViewController {
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
    
    // Clean typealiases for all protocol compositions
    typealias DataObjectWithMetadata = BRCDataObject & BRCMetadataProtocol
    typealias ThumbnailDataObject = BRCDataObject & BRCThumbnailProtocol & BRCMetadataProtocol  
    typealias ProcessableObject = BRCDataObject & BRCThumbnailProtocol
    typealias ColorableMetadata = BRCObjectMetadata & BRCThumbnailImageColorsProtocol
    
    /** Collections to process for object operations */
    private let collections = [BRCArtObject.yapCollection, BRCCampObject.yapCollection]
    
    @objc func prefetchAllColors() {
        DispatchQueue.global(qos: .default).async {
            var allObjects: [(ProcessableObject, ColorableMetadata)] = []
            
            self.backgroundReadConnection.read { transaction in
                for collection in self.collections {
                    transaction.iterateRows(inCollection: collection) { (key, obj: BRCDataObject, metadata: BRCObjectMetadata?, stop) in
                        if let thumbnailObj = obj as? ThumbnailDataObject,
                           let objMetadata = thumbnailObj.metadata(with: transaction) as? ColorableMetadata,
                           objMetadata.thumbnailImageColors == nil,
                           thumbnailObj.localThumbnailURL != nil {
                            allObjects.append((thumbnailObj, objMetadata))
                        }
                    }
                }
            }
            
            // Process all objects uniformly
            allObjects.forEach({ (obj, metadata) in
                autoreleasepool {
                    guard let image = BRCMediaDownloader.imageForObject(obj) else {
                        return
                    }
                    self.getColors(object: obj, metadata: metadata, image: image, downscaleSize: .zero, processingQueue: nil, completion: nil)
                }
            })
        }
    }
    
    /** Processes objects missing color metadata. Useful for newly added objects. */
    @objc func processMissingColors() {
        DispatchQueue.global(qos: .default).async {
            var allObjects: [(ProcessableObject, ColorableMetadata)] = []
            
            self.backgroundReadConnection.read { transaction in
                for collection in self.collections {
                    transaction.iterateRows(inCollection: collection) { (key, obj: BRCDataObject, metadata: BRCObjectMetadata?, stop) in
                        if let thumbnailObj = obj as? ThumbnailDataObject,
                           let objMetadata = thumbnailObj.metadata(with: transaction) as? ColorableMetadata,
                           objMetadata.thumbnailImageColors == nil,
                           thumbnailObj.localThumbnailURL != nil {
                            allObjects.append((thumbnailObj, objMetadata))
                        }
                    }
                }
            }
            
            NSLog("ColorCache: Processing %d objects missing colors", allObjects.count)
            
            // Process all objects uniformly
            allObjects.forEach({ (obj, metadata) in
                autoreleasepool {
                    guard let image = BRCMediaDownloader.imageForObject(obj) else {
                        return
                    }
                    self.getColors(object: obj, metadata: metadata, image: image, downscaleSize: .zero, processingQueue: nil, completion: nil)
                }
            })
        }
    }
    
    /** Generic color computation for any object with thumbnail image colors. If processingQueue is nil, it will execute block on current queue */
    func getColors<DataObject: DataObjectWithMetadata, Metadata: ColorableMetadata>(
        object: DataObject,
        metadata: Metadata,
        image: UIImage,
        downscaleSize: CGSize,
        processingQueue: DispatchQueue?,
        completion: ((BRCImageColors)->Void)?
    ) {
        // If image colors theming is disabled, return global theme colors
        if !Appearance.useImageColorsTheming {
            if let completion = completion {
                self.completionQueue.async {
                    completion(Appearance.currentColors)
                }
            }
            return
        }
        
        // Found colors in cache
        if let colors = metadata.thumbnailImageColors {
            if let completion = completion {
                self.completionQueue.async {
                    completion(colors)
                }
            }
            return
        }
        
        let processBlock = {
            // Maybe find colors in database when given stale metadata
            var existingColors: BRCImageColors? = nil
            self.backgroundReadConnection.read { transaction in
                let freshMetadata = object.metadata(with: transaction)
                if let colorMetadata = freshMetadata as? BRCThumbnailImageColorsProtocol {
                    existingColors = colorMetadata.thumbnailImageColors
                }
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
            let brcColors: BRCImageColors? = autoreleasepool {
                let colors = image.getColors(quality: .high)
                return colors?.brc_ImageColors
            }
            
            guard let extractedColors = brcColors else {
                return
            }
            
            if let completion = completion {
                self.completionQueue.async {
                    completion(extractedColors)
                }
            }
            
            self.writeConnection.asyncReadWrite { transaction in
                let metadata = object.metadata(with: transaction).metadataCopy()
                if let colorMetadata = metadata as? BRCThumbnailImageColorsProtocol {
                    colorMetadata.thumbnailImageColors = extractedColors
                    object.replace(metadata, transaction: transaction)
                }
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
