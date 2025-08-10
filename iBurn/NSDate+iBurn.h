//
//  NSDate+iBurn.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/31/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSDate (iBurn)

+ (NSInteger)brc_daysBetweenDate:(NSDate*)fromDateTime andDate:(NSDate*)toDateTime;
- (NSDate*) brc_nextDay;

/** Returns self if within range, or startDate if out of range. */
- (NSDate*) brc_dateWithinStartDate:(NSDate*)startDate
                            endDate:(NSDate*)endDate;

#if DEBUG
/** Used for testing events */
+ (NSDate*) brc_testDate;

/** Set a custom override date for testing */
+ (void) brc_setOverrideDate:(NSDate*)overrideDate;

/** Get the current override date (nil if using default) */
+ (NSDate*) brc_currentOverrideDate;

/** Clear the custom override date */
+ (void) brc_clearOverrideDate;
#endif

@end
