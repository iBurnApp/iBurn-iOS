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

- (void) setDataObject:(BRCDataObject*)dataObject {
    _dataObject = dataObject;
    CLLocationDistance distance = dataObject.distanceFromUser;
    if (distance == CLLocationDistanceMax || distance == 0) {
        self.subtitleLabel.text = @"";
    } else {
        self.subtitleLabel.attributedText = [TTTLocationFormatter brc_humanizedStringForDistance:distance];
    }
    
    self.titleLabel.text = dataObject.title;
    UIFont *font = self.titleLabel.font;
    UIFont *newFont = nil;
    if (dataObject.isFavorite) {
        newFont = [UIFont fontWithDescriptor:[[font fontDescriptor] fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold] size:font.pointSize];
    } else {
        newFont = [UIFont fontWithDescriptor:[[font fontDescriptor] fontDescriptorWithSymbolicTraits:0] size:font.pointSize];
    }
    self.titleLabel.font = newFont;
}

+ (NSString*) cellIdentifier {
    return NSStringFromClass([self class]);
}

+ (CGFloat) cellHeight {
    return 67.0f;
}

@end
