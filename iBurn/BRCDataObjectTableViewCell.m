//
//  BRCDataObjectTableViewCell.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataObjectTableViewCell.h"
#import "BRCDataObject.h"

@implementation BRCDataObjectTableViewCell

- (void) setDataObject:(BRCDataObject*)dataObject {
    self.titleLabel.text = dataObject.title;
    CLLocationDistance distance = dataObject.distanceFromUser;
    if (distance == DBL_MAX || distance == 0) {
        self.subtitleLabel.text = nil;
    } else {
        self.subtitleLabel.text = [NSString stringWithFormat:@"%0.1f m away", distance];
    }
}

+ (NSString*) cellIdentifier {
    return NSStringFromClass([self class]);
}

+ (CGFloat) cellHeight {
    return 67.0f;
}

@end
