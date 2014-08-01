//
//  TTTLocationFormatter+iBurn.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/1/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "TTTLocationFormatter+iBurn.h"
#import "TTTTimeIntervalFormatter+iBurn.h"

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
        return [UIColor colorWithRed:43/255.0f green:206/255.0f blue:18/255.0f alpha:1.0f];
    } else if (timeInterval >= easyWalk && timeInterval < hardWalk) {
        return [UIColor colorWithRed:249/255.0f green:175/255.0f blue:14/255.0f alpha:1.0f];
    } else if (timeInterval >= hardWalk) {
        return [UIColor colorWithRed:219/255.0f green:23/255.0f blue:19/255.0f alpha:1.0f];
    }
    return nil;
}

+ (NSAttributedString*) brc_humanizedStringForDistance:(CLLocationDistance)distance {
    NSTimeInterval secondsToWalk = [TTTLocationFormatter brc_timeIntervalForWalkingDistance:distance];
    NSString *timeString = [[TTTTimeIntervalFormatter brc_walkingTimeFormatter] stringForTimeInterval:secondsToWalk];
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
