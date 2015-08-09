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
#import "BRCDatabaseManager.h"

@implementation BRCDataObjectTableViewCell
@synthesize dataObject = _dataObject;

- (void) setDataObject:(BRCDataObject*)dataObject {
    _dataObject = [dataObject copy];
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
        self.rightSubtitleLabel.text = playaLocation;
    }
    self.favoriteButton.selected = dataObject.isFavorite;
}

- (void) updateDistanceLabelFromLocation:(CLLocation*)fromLocation {
    CLLocation *recentLocation = fromLocation;
    CLLocation *objectLocation = self.dataObject.location;
    CLLocationDistance distance = CLLocationDistanceMax;
    if (recentLocation && objectLocation) {
        distance = [objectLocation distanceFromLocation:recentLocation];
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
    BRCDataObject *dataObject = [self.dataObject copy];
    dataObject.isFavorite = self.favoriteButton.selected;
    // not the best place to do this
    [[BRCDatabaseManager sharedInstance].readWriteConnection asyncReadWriteWithBlock:^(YapDatabaseReadWriteTransaction * transaction) {
        [transaction setObject:dataObject forKey:dataObject.uniqueID inCollection:[[dataObject class] collection]];
    }];
}

@end
