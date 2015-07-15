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

@implementation BRCDataObjectTableViewCell

- (void) setStyleFromDataObject:(BRCDataObject*)dataObject {
    self.titleLabel.text = dataObject.title;
    // right now the 2015 API reponses are kind of sparse
    if ([dataObject isKindOfClass:[BRCArtObject class]]) {
        BRCArtObject *art = (BRCArtObject*)dataObject;
        self.descriptionLabel.text = art.artistName;
    } else {
        NSString *detailString = [dataObject.detailDescription stringByReplacingOccurrencesOfString:@"\r\n" withString:@" "];
        self.descriptionLabel.text = detailString;
    }
}

- (void) updateDistanceLabelFromLocation:(CLLocation*)fromLocation toLocation:(CLLocation*)toLocation {
    CLLocation *recentLocation = fromLocation;
    CLLocation *objectLocation = toLocation;
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

@end
