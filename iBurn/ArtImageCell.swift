//
//  ArtImageCell.swift
//  iBurn
//
//  Created by Chris Ballinger on 8/7/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

import UIKit
import Kingfisher

@objc(ArtImageCell)
public class ArtImageCell: BRCArtObjectTableViewCell {
    
    @IBOutlet var thumbnailView: UIImageView!
    
    override public func setDataObject(_ dataObject: BRCDataObject, metadata: BRCObjectMetadata) {
        super.setDataObject(dataObject, metadata: metadata)
        guard let art = dataObject as? BRCArtObject,
        let thumbnailURL = art.thumbnailURL else {
            return
        }
        thumbnailView.kf.cancelDownloadTask()
        thumbnailView.kf.indicatorType = .activity
        thumbnailView.kf.setImage(with: thumbnailURL, completionHandler: { image, error, cacheType, imageUrl in
            guard let image = image else { return }
            ColorCache.shared.getColors(image: image, completion: { colors in
                UIView.animate(withDuration: 0.25, delay: 0.0, options: [], animations: {
                    self.backgroundColor = colors.background
                    self.titleLabel.textColor = colors.primary
                    self.subtitleLabel.textColor = colors.secondary
                    self.rightSubtitleLabel.textColor = colors.secondary
                    self.descriptionLabel.textColor = colors.detail
                })
            })
        })
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        if let image = thumbnailView.image {
            ColorCache.shared.cancelColors(image: image)
        }
        
        self.backgroundColor = UIColor.white
        thumbnailView.image = nil
        thumbnailView.kf.cancelDownloadTask()
        self.titleLabel.textColor = UIColor.darkText
        self.subtitleLabel.textColor = UIColor.lightGray
        self.rightSubtitleLabel.textColor = UIColor.lightGray
        self.descriptionLabel.textColor = UIColor.darkText
    }
}
