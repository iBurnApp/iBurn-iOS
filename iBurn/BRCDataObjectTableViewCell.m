//
//  BRCDataObjectTableViewCell.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataObjectTableViewCell.h"
#import "BRCDataObject.h"
#import "TTTLocationFormatter+iBurn.h"
#import "BRCArtObject.h"
#import "BRCEventObject.h"
#import "BRCEventObjectTableViewCell.h"
#import "BRCArtObjectTableViewCell.h"
#import "BRCDatabaseManager.h"
#import "BRCEmbargo.h"
#import <Mantle/Mantle.h>
#import "iBurn-Swift.h"

@implementation BRCDataObjectTableViewCell

- (void) setDataObject:(BRCDataObject*)dataObject metadata:(BRCObjectMetadata*)metadata {
    self.titleLabel.text = dataObject.title;
    // strip those newlines rull good
    NSString *detailString = [dataObject.detailDescription stringByReplacingOccurrencesOfString:@"\r\n" withString:@" "];
    detailString = [detailString stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    self.descriptionLabel.text = detailString;
    if ([dataObject isKindOfClass:[BRCArtObject class]]) {
        BRCArtObject *art = (BRCArtObject*)dataObject;
        self.rightSubtitleLabel.text = art.artistName;
    } else {
        [self setupLocationLabel:self.rightSubtitleLabel dataObject:dataObject];
    }
    self.favoriteButton.selected = metadata.isFavorite;
}

- (void) setupLocationLabel:(UILabel*)label dataObject:(BRCDataObject*)dataObject {
    NSString *playaLocation = dataObject.playaLocation;
    if (!playaLocation) {
        playaLocation = @"0:00 & ?";
    }
    if ([BRCEmbargo canShowLocationForObject:dataObject]) {
        label.text = playaLocation;
    } else if (dataObject.burnerMapLocationString) {
        NSString *burnerMapAddress = dataObject.shortBurnerMapAddress;
        if (!burnerMapAddress) {
            burnerMapAddress = dataObject.burnerMapLocationString;
        }
        label.text = [NSString stringWithFormat:@"BurnerMap: %@",burnerMapAddress];
    } else {
        label.text = @"Location Restricted";
    }
}

- (void) updateDistanceLabelFromLocation:(CLLocation*)fromLocation dataObject:(BRCDataObject *)dataObject {
    CLLocation *recentLocation = fromLocation;
    CLLocationDistance distance = CLLocationDistanceMax;
    if (recentLocation) {
        distance = [dataObject distanceFromLocation:recentLocation];
    }
    if (distance == CLLocationDistanceMax || distance == 0) {
        self.subtitleLabel.text = @"🚶🏽 ? min   🚴🏽 ? min";
    } else {
        self.subtitleLabel.attributedText = [TTTLocationFormatter brc_humanizedStringForDistance:distance];
    }
}

+ (NSString*) cellIdentifier {
    return NSStringFromClass(self.class);
}

- (IBAction)favoriteButtonPressed:(id)sender {
    if (self.favoriteButton.selected) {
        [self.favoriteButton deselect];
    } else {
        [self.favoriteButton select];
    }
    if (self.favoriteButtonAction) {
        self.favoriteButtonAction(self);
    }
}

@end
