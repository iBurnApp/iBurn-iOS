//
//  BRCImageColors.m
//  iBurn
//
//  Created by Chris Ballinger on 8/8/17.
//  Copyright © 2017 Burning Man Earth. All rights reserved.
//

#import "BRCImageColors.h"

@implementation BRCImageColors

- (instancetype) initWithBackgroundColor:(UIColor*)backgroundColor
                            primaryColor:(UIColor*)primaryColor
                          secondaryColor:(UIColor*)secondaryColor
                             detailColor:(UIColor*)detailColor {
    if (self = [super init]) {
        _backgroundColor = backgroundColor;
        _primaryColor = primaryColor;
        _secondaryColor = secondaryColor;
        _detailColor = detailColor;
    }
    return self;
}

+ (BRCImageColors*) plain {
    BRCImageColors *colors = [[BRCImageColors alloc] initWithBackgroundColor:UIColor.whiteColor primaryColor:UIColor.darkTextColor secondaryColor:UIColor.darkTextColor detailColor:UIColor.lightGrayColor];
    return colors;
}

@end
