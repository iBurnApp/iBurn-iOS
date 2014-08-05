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
#import "BRCLocationManager.h"

@implementation BRCDataObjectTableViewCell

- (void) setDataObject:(BRCDataObject*)dataObject {
    _dataObject = dataObject;
    CLLocation *recentLocation = [BRCLocationManager sharedInstance].recentLocation;
    CLLocation *objectLocation = dataObject.location;
    CLLocationDistance distance = CLLocationDistanceMax;
    if (recentLocation && objectLocation) {
        distance = [objectLocation distanceFromLocation:recentLocation];
    }
    if (distance == CLLocationDistanceMax || distance == 0) {
        self.subtitleLabel.text = @"";
    } else {
        self.subtitleLabel.attributedText = [TTTLocationFormatter brc_humanizedStringForDistance:distance];
    }
    
    self.titleLabel.text = dataObject.title;
    
    [self setTitleLabelBold:dataObject.isFavorite];
}

+ (NSString*) cellIdentifier {
    return NSStringFromClass([self class]);
}

+ (CGFloat) cellHeight {
    return 67.0f;
}

- (void) setTitleLabelBold:(BOOL)isBold {
    UIFont *font = self.titleLabel.font;
    UIFont *newFont = nil;
    if (isBold) {
        newFont = [UIFont fontWithDescriptor:[[font fontDescriptor] fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold] size:font.pointSize];
    } else {
        newFont = [UIFont fontWithDescriptor:[[font fontDescriptor] fontDescriptorWithSymbolicTraits:0] size:font.pointSize];
    }
    self.titleLabel.font = newFont;
}

@end
