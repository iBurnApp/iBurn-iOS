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
        guard let art = dataObject as? BRCArtObject,
        let artMetadata = metadata as? BRCArtMetadata else {
                return
        }

        if let colors = artMetadata.thumbnailImageColors {
            setupLabelColors(colors)
        }
        guard let image = BRCMediaDownloader.imageForArt(art) else {
            return
        }
        self.thumbnailView.image = image
        guard artMetadata.thumbnailImageColors == nil else { return }
        DispatchQueue.global(qos: .default).async {
            ColorCache.shared.getColors(art: art, artMetadata: artMetadata, image: image, downscaleSize: .zero, processingQueue: nil, completion: { colors in
                guard self.objectUniqueId == dataObject.uniqueID else { return }
                UIView.animate(withDuration: 0.25, delay: 0.0, options: [], animations: {
                    self.setupLabelColors(colors)
                })
            })
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
