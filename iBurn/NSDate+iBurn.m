//
//  NSDate+iBurn.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/31/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "NSDate+iBurn.h"
#import "NSDateFormatter+iBurn.h"

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
    
    [calendar rangeOfUnit:NSCalendarUnitDay startDate:&fromDate
                 interval:NULL forDate:fromDateTime];
    [calendar rangeOfUnit:NSCalendarUnitDay startDate:&toDate
                 interval:NULL forDate:toDateTime];
    
    NSDateComponents *difference = [calendar components:NSCalendarUnitDay
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


/** Returns self if within range, or startDate if out of range. */
- (NSDate*) brc_dateWithinStartDate:(NSDate*)startDate
                            endDate:(NSDate*)endDate {
    NSDate *dayCandidate = self;
    NSDate *validDate = nil;
    if ([dayCandidate compare:startDate] == NSOrderedDescending && [dayCandidate compare:endDate] == NSOrderedAscending) {
        validDate = dayCandidate;
    } else {
        validDate = startDate;
    }
    return validDate;
}

+ (NSDate*) brc_testDate {
    NSDateFormatter *df = [NSDateFormatter brc_playaEventsAPIDateFormatter];
    NSString *testDateString = @"2016-09-01T11:00:00-07:00";
    NSDate *date = [df dateFromString:testDateString];
    NSParameterAssert(date);
    return date;
}

@end
