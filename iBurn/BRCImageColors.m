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
    // Supposedly the default tint on iOS
    // https://stackoverflow.com/a/19033293/805882
    UIColor *defaultTint = [UIColor colorWithRed:0.0 green:122.0/255.0 blue:1.0 alpha:1.0];
    
    BRCImageColors *colors = [[BRCImageColors alloc] initWithBackgroundColor:UIColor.whiteColor primaryColor:UIColor.darkTextColor secondaryColor:defaultTint detailColor:UIColor.lightGrayColor];
    return colors;
}

@end
