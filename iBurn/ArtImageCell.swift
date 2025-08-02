//
//  ArtImageCell.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/7/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import UIKit

@objc(ArtImageCell)
public class ArtImageCell: BRCArtObjectTableViewCell {
    
    /// to prevent reloading cells images that dont match current state
    private var objectUniqueId: String = ""
    @IBOutlet var thumbnailView: UIImageView!

    override public func setDataObject(_ dataObject: BRCDataObject, metadata: BRCObjectMetadata) {
        super.setDataObject(dataObject, metadata: metadata)
        objectUniqueId = dataObject.uniqueID
        
        // Check if object supports thumbnails
        guard dataObject is BRCThumbnailProtocol else {
            return
        }
        
        // Get image from object (works for any thumbnail-capable object)
        guard let thumbnailImage = getImageForObject(dataObject) else {
            return
        }
        
        // Get cached colors from metadata if image colors theming is enabled
        let imageColors = Appearance.useImageColorsTheming ? getImageColorsFromMetadata(metadata) : nil
        if let colors = imageColors {
            setupLabelColors(colors)
        } else if !Appearance.useImageColorsTheming {
            // Use global theme colors when toggle is disabled
            setupLabelColors(Appearance.currentColors)
        }
        
        self.thumbnailView.image = thumbnailImage
        
        // Process colors if not cached and image colors theming is enabled
        if imageColors == nil && Appearance.useImageColorsTheming {
            processImageColors(for: dataObject, metadata: metadata, image: thumbnailImage)
        }
    }
    
    private func getImageForObject(_ dataObject: BRCDataObject) -> UIImage? {
        guard let thumbnailObject = dataObject as? BRCThumbnailProtocol,
              let localURL = thumbnailObject.localThumbnailURL else {
            return nil
        }
        return UIImage(contentsOfFile: localURL.path)
    }
    
    private func getImageColorsFromMetadata(_ metadata: BRCObjectMetadata) -> BRCImageColors? {
        if let artMetadata = metadata as? BRCArtMetadata {
            return artMetadata.thumbnailImageColors
        } else if let campMetadata = metadata as? BRCCampMetadata {
            return campMetadata.thumbnailImageColors
        }
        return nil
    }
    
    private func processImageColors(for dataObject: BRCDataObject, metadata: BRCObjectMetadata, image: UIImage) {
        DispatchQueue.global(qos: .default).async {
            // Use ColorCache for art objects, fallback to simple extraction for others
            if let art = dataObject as? BRCArtObject,
               let artMetadata = metadata as? BRCArtMetadata {
                ColorCache.shared.getColors(object: art, metadata: artMetadata, image: image, downscaleSize: .zero, processingQueue: nil, completion: { colors in
                    guard self.objectUniqueId == dataObject.uniqueID else { return }
                    DispatchQueue.main.async {
                        UIView.animate(withDuration: 0.25, delay: 0.0, options: [], animations: {
                            self.setupLabelColors(colors)
                        })
                    }
                })
            } else {
                // Use simple color extraction for non-art objects
                let colors = image.getColors()?.brc_ImageColors ?? Appearance.currentColors
                
                // Update metadata with colors
                if let campMetadata = metadata as? BRCCampMetadata {
                    campMetadata.thumbnailImageColors = colors
                    let metadataObject = dataObject as BRCMetadataProtocol
                    BRCDatabaseManager.shared.readWriteConnection.asyncReadWrite { transaction in
                        metadataObject.replace(campMetadata, transaction: transaction)
                    }
                }
                
                guard self.objectUniqueId == dataObject.uniqueID else { return }
                DispatchQueue.main.async {
                    UIView.animate(withDuration: 0.25, delay: 0.0, options: [], animations: {
                        self.setupLabelColors(colors)
                    })
                }
            }
        }
    }


    private func setupLabelColors(_ colors: BRCImageColors) {
        self.backgroundColor = colors.backgroundColor
        self.titleLabel.textColor = colors.primaryColor
        //self.subtitleLabel.textColor = colors.secondaryColor
        self.rightSubtitleLabel.textColor = colors.secondaryColor
        self.descriptionLabel.textColor = colors.detailColor
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        self.backgroundColor = UIColor.systemBackground
        thumbnailView.image = nil
        self.titleLabel.textColor = UIColor.label
        //self.subtitleLabel.textColor = UIColor.lightGray
        self.rightSubtitleLabel.textColor = UIColor.secondaryLabel
        self.descriptionLabel.textColor = UIColor.label
    }
}
