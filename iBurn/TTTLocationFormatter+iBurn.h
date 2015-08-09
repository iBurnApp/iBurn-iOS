//
//  TTTLocationFormatter+iBurn.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/1/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "TTTLocationFormatter.h"


@interface TTTLocationFormatter (iBurn)

+ (instancetype) brc_distanceFormatter;

/**
 *  How easy it is to walk in color form
 *  20 minute walk - green
 *  35 minute walk - orange
 *  >=35 minite walk - red
 */
+ (UIColor*) brc_colorForTimeInterval:(NSTimeInterval)timeInterval;

/**
 *  Return a walk-focused string
 *  ex:  8 mins away (0.44 miles)
 */
+ (NSAttributedString*) brc_humanizedStringForDistance:(CLLocationDistance)distance;

@end
