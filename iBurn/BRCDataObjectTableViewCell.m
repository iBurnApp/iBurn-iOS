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
#import "PFAnalytics+iBurn.h"
#import "BRCEmbargo.h"
#import <Mantle/Mantle.h>
#import <Parse/Parse.h>

@implementation BRCDataObjectTableViewCell

- (void) setDataObject:(BRCDataObject*)dataObject {
    self.titleLabel.text = dataObject.title;
    // strip those newlines rull good
    NSString *detailString = [dataObject.detailDescription stringByReplacingOccurrencesOfString:@"\r\n" withString:@" "];
    detailString = [detailString stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    self.descriptionLabel.text = detailString;
    if ([dataObject isKindOfClass:[BRCArtObject class]]) {
        BRCArtObject *art = (BRCArtObject*)dataObject;
        self.rightSubtitleLabel.text = art.artistName;
    } else {
        NSString *playaLocation = dataObject.playaLocation;
        if (!playaLocation) {
            playaLocation = @"0:00 & ?";
        }
        if ([BRCEmbargo canShowLocationForObject:dataObject]) {
            self.rightSubtitleLabel.text = playaLocation;
        } else {
            self.rightSubtitleLabel.text = @"Location Restricted";
        }
    }
    self.favoriteButton.selected = dataObject.isFavorite;
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
    return NSStringFromClass([self class]);
}

+ (Class) cellClassForDataObjectClass:(Class)dataObjectClass {
    if (dataObjectClass == [BRCEventObject class]) {
        return [BRCEventObjectTableViewCell class];
    } else if (dataObjectClass == [BRCArtObject class]) {
        return [BRCArtObjectTableViewCell class];
    } else {
        return [BRCDataObjectTableViewCell class];
    }
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
