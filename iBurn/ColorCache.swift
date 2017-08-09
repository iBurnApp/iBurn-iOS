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
