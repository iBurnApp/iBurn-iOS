//
//  BRCGeocoder.m
//  iBurn
//
//  Created by David Chiles on 8/5/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import "BRCGeocoder.h"
@import BButton;
@import JavaScriptCore;
#import "iBurn-Swift.h"

@implementation NSString (BRCGeocoder)
/** Add font-awesome crosshairs */
- (NSAttributedString*) brc_attributedLocationStringWithCrosshairs {
    BRCImageColors *colors = Appearance.currentColors;
    NSString *locationString = self;
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] init];
    NSAttributedString *crosshairs = [[NSAttributedString alloc] initWithString:[NSString fa_stringForFontAwesomeIcon:FACrosshairs] attributes:@{NSFontAttributeName: [UIFont fontWithName:kFontAwesomeFont size:17],
                                                                                                                                                 NSForegroundColorAttributeName: colors.detailColor
                                                                                                                                                 }];
    [string appendAttributedString:crosshairs];
    [string appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
    NSAttributedString *location = [[NSAttributedString alloc] initWithString:locationString attributes:@{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline],
                                                                                                          NSForegroundColorAttributeName: colors.primaryColor
                                                                                                          
                                                                                                          }];
    [string appendAttributedString:location];
    return string;
}
@end

