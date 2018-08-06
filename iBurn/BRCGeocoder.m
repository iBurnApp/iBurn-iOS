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

@implementation NSString (BRCGeocoder)
/** Add font-awesome crosshairs */
- (NSAttributedString*) brc_attributedLocationStringWithCrosshairs {
    NSString *locationString = self;
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc] init];
    NSAttributedString *crosshairs = [[NSAttributedString alloc] initWithString:[NSString fa_stringForFontAwesomeIcon:FACrosshairs] attributes:@{NSFontAttributeName: [UIFont fontWithName:kFontAwesomeFont size:17]}];
    [string appendAttributedString:crosshairs];
    [string appendAttributedString:[[NSAttributedString alloc] initWithString:@" "]];
    NSAttributedString *location = [[NSAttributedString alloc] initWithString:locationString attributes:@{NSFontAttributeName: [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline]}];
    [string appendAttributedString:location];
    return string;
}
@end

