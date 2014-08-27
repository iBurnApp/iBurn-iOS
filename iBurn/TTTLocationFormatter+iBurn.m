//
//  TTTLocationFormatter+iBurn.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/1/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "TTTLocationFormatter+iBurn.h"
#import "TTTTimeIntervalFormatter+iBurn.h"
#import "UIColor+iBurn.h"

@implementation TTTLocationFormatter (iBurn)

+ (instancetype) brc_distanceFormatter {
    static TTTLocationFormatter *distanceFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        distanceFormatter = [[TTTLocationFormatter alloc] init];
        distanceFormatter.numberFormatter.roundingMode = NSNumberFormatterRoundHalfUp;
        distanceFormatter.numberFormatter.formatWidth = 2;
    });
    return distanceFormatter;
}

+ (NSTimeInterval) brc_timeIntervalForWalkingDistance:(CLLocationDistance)distance {
    double averageHumanWalkingSpeedFactor = 0.72; // in seconds/meter == 3.1 mph
    return averageHumanWalkingSpeedFactor * distance;
}

/**
 *  How easy it is to walk in color form
 *  20 minute walk - green
 *  35 minute walk - orange
 *  >=35 minite walk - red
 */
+ (UIColor*) brc_colorForTimeInterval:(NSTimeInterval)timeInterval {
    double easyWalk = 20 * 60; // 20 minutes
    double hardWalk = 35 * 60; // 35 minutes
    if (timeInterval < easyWalk) {
        return [UIColor brc_greenColor];
    } else if (timeInterval >= easyWalk && timeInterval < hardWalk) {
        return [UIColor brc_orangeColor];
    } else if (timeInterval >= hardWalk) {
        return [UIColor brc_redColor];
    }
    return nil;
}

+ (NSAttributedString*) brc_humanizedStringForDistance:(CLLocationDistance)distance {
    NSTimeInterval secondsToWalk = [TTTLocationFormatter brc_timeIntervalForWalkingDistance:distance];
    NSString *timeString = [[TTTTimeIntervalFormatter brc_shortRelativeTimeFormatter] stringForTimeInterval:secondsToWalk];
    if (!timeString) {
        return nil;
    }
    NSString *distanceString = [[TTTLocationFormatter brc_distanceFormatter] stringFromDistance:distance];
    NSMutableString *fullString = [NSMutableString string];
    [fullString appendFormat:@"%@ ", timeString];
    if (distanceString) {
        [fullString appendFormat:@"%@", distanceString];
    }
    NSMutableAttributedString *coloredText = [[NSMutableAttributedString alloc] initWithString:fullString];
    UIColor *timeColor = [self brc_colorForTimeInterval:secondsToWalk];
    NSRange timeRange = NSMakeRange(0, timeString.length);
    [coloredText setAttributes:@{NSForegroundColorAttributeName: timeColor}
                         range:timeRange];
    return coloredText;
}

@end
