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


static const double kAverageHumanWalkingSpeedFactor = 0.72; // in seconds/meter == 3.1 mph
static const double kAverageHumanBikingSpeedFactor = 0.232258065; // in seconds/meter == 9.6 mph

/**
 *  Returns estimated walking time, calculated by distance in meters x 0.72 seconds/meter
 * for the average human walking speed of 3.1 mph.
 *
 *  @param distance meters away
 *
 *  @return estimated walking time in seconds
 */
static NSTimeInterval BRCTimeIntervalForWalkingDistance(CLLocationDistance distance) {
    return kAverageHumanWalkingSpeedFactor * distance;
}

/** For cyclists in Copenhagen, the average cycling speed is 15.5 km/h (9.6 mph) */
static NSTimeInterval BRCTimeIntervalForBikingDistance(CLLocationDistance distance) {
    return kAverageHumanBikingSpeedFactor * distance;
}

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

// @"🚶🏽 ? min   🚴🏽 ? min"
+ (NSAttributedString*) brc_humanizedStringForDistance:(CLLocationDistance)distance {
    NSTimeInterval secondsToWalk = BRCTimeIntervalForWalkingDistance(distance);
    NSTimeInterval secondsToBike = BRCTimeIntervalForBikingDistance(distance);

    NSString *walkingTimeString = [[TTTTimeIntervalFormatter brc_shortRelativeTimeFormatter] stringForTimeInterval:secondsToWalk];
    NSString *bikingTimeString = [[TTTTimeIntervalFormatter brc_shortRelativeTimeFormatter] stringForTimeInterval:secondsToBike];
    if (!walkingTimeString || !bikingTimeString) {
        return nil;
    }
    NSString *estimatesString = [NSString stringWithFormat:@"🚶🏽 %@   🚴🏽 %@", walkingTimeString, bikingTimeString];
    NSMutableAttributedString *coloredText = [[NSMutableAttributedString alloc] initWithString:estimatesString];
    UIColor *walkColor = [self brc_colorForTimeInterval:secondsToWalk];
    UIColor *bikeColor = [self brc_colorForTimeInterval:secondsToBike];
    NSRange walkRange = [estimatesString rangeOfString:walkingTimeString];
    NSRange bikeRange = [estimatesString rangeOfString:bikingTimeString];
    [coloredText setAttributes:@{NSForegroundColorAttributeName: walkColor}
                         range:walkRange];
    [coloredText setAttributes:@{NSForegroundColorAttributeName: bikeColor}
                         range:bikeRange];
    return coloredText;
}

@end
