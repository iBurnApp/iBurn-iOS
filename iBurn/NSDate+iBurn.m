//
//  NSDate+iBurn.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/31/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "NSDate+iBurn.h"

@implementation NSDate (iBurn)

// http://stackoverflow.com/a/4739650/805882
+ (NSInteger)brc_daysBetweenDate:(NSDate*)fromDateTime andDate:(NSDate*)toDateTime
{
    NSParameterAssert(fromDateTime != nil);
    NSParameterAssert(toDateTime != nil);
    if (!fromDateTime || !toDateTime) {
        return NSIntegerMax;
    }
    NSDate *fromDate;
    NSDate *toDate;
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    
    [calendar rangeOfUnit:NSDayCalendarUnit startDate:&fromDate
                 interval:NULL forDate:fromDateTime];
    [calendar rangeOfUnit:NSDayCalendarUnit startDate:&toDate
                 interval:NULL forDate:toDateTime];
    
    NSDateComponents *difference = [calendar components:NSDayCalendarUnit
                                               fromDate:fromDate toDate:toDate options:0];
    
    return [difference day];
}

- (NSDate*) brc_nextDay {
    NSDateComponents *dayComponent = [[NSDateComponents alloc] init];
    dayComponent.day = 1;
    NSCalendar *theCalendar = [NSCalendar currentCalendar];
    NSDate *nextDate = [theCalendar dateByAddingComponents:dayComponent toDate:self options:0];
    return nextDate;
}

@end
