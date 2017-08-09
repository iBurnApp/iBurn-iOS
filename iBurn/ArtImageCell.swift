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
    
    @IBOutlet var thumbnailView: UIImageView!

    static let downscaleSize = CGSize(width: 200, height: 200)

    override public func setDataObject(_ dataObject: BRCDataObject, metadata: BRCObjectMetadata) {
        super.setDataObject(dataObject, metadata: metadata)
        guard let art = dataObject as? BRCArtObject,
        let artMetadata = metadata as? BRCArtMetadata,
        let thumbnailURL = art.thumbnailURL else {
            return
        }


        if let colors = artMetadata.thumbnailImageColors {
            setupLabelColors(colors)
        }

        DispatchQueue.global(qos: .userInteractive).async {
            guard let url = art.localThumbnailURL,
                let image = UIImage(contentsOfFile: url.path) else {
                return
            }
            DispatchQueue.main.async {
                self.thumbnailView.image = image
            }
            guard artMetadata.thumbnailImageColors == nil else { return }
            ColorCache.shared.getColors(art: art, artMetadata: artMetadata, image: image, downscaleSize: ArtImageCell.downscaleSize, completion: { colors in
                UIView.animate(withDuration: 0.25, delay: 0.0, options: [], animations: {
                    self.setupLabelColors(colors)
                })
            })
        }
        NSLog("contentView: \(self.contentView.constraints)")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        self.updateConstraints()
    }

    public override func updateConstraints() {
        super.updateConstraints()
        NSLog("contentView: \(self.contentView.constraints)")
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
        self.backgroundColor = UIColor.white
        thumbnailView.image = nil
        self.titleLabel.textColor = UIColor.darkText
        //self.subtitleLabel.textColor = UIColor.lightGray
        self.rightSubtitleLabel.textColor = UIColor.lightGray
        self.descriptionLabel.textColor = UIColor.darkText
    }
}
