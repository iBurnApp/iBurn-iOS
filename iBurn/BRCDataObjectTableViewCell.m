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
    self.titleLabel.text = dataObject.title;
    CLLocationDistance distance = dataObject.distanceFromUser;
    if (distance == CLLocationDistanceMax || distance == 0) {
        self.subtitleLabel.text = nil;
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

@end
