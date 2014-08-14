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

@implementation BRCDataObjectTableViewCell

- (void) setStyleFromDataObject:(BRCDataObject*)dataObject {
    self.titleLabel.text = dataObject.title;
    [self setTitleLabelBold:dataObject.isFavorite];
}

- (void) updateDistanceLabelFromLocation:(CLLocation*)fromLocation toLocation:(CLLocation*)toLocation {
    CLLocation *recentLocation = fromLocation;
    CLLocation *objectLocation = toLocation;
    CLLocationDistance distance = CLLocationDistanceMax;
    if (recentLocation && objectLocation) {
        distance = [objectLocation distanceFromLocation:recentLocation];
    }
    if (distance == CLLocationDistanceMax || distance == 0) {
        self.subtitleLabel.text = @"No Location";
    } else {
        self.subtitleLabel.attributedText = [TTTLocationFormatter brc_humanizedStringForDistance:distance];
    }
}


+ (NSString*) cellIdentifier {
    return NSStringFromClass([self class]);
}

+ (CGFloat) cellHeight {
    return 67.0f;
}

- (void) setTitleLabelBold:(BOOL)isBold {
    UIFont *newFont = nil;
    if (isBold) {
        newFont = [UIFont boldSystemFontOfSize:18];
    } else {
        newFont = [UIFont systemFontOfSize:18];
    }
    NSParameterAssert(newFont != nil);
    self.titleLabel.font = newFont;
}

@end
