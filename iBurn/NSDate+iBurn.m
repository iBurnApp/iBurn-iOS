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

static NSDate *_customOverrideDate = nil;

+ (NSDate*) brc_testDate {
    // First check if we have a custom override date set
    if (_customOverrideDate) {
        return _customOverrideDate;
    }
    
    // Check UserDefaults for persisted override date
    NSDate *savedDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"BRCMockDateValue"];
    if (savedDate) {
        return savedDate;
    }
    
    // Fall back to default test date
    NSDateFormatter *df = [NSDateFormatter brc_playaEventsAPIDateFormatter];
    NSString *testDateString = @"2025-08-29T11:00:00-07:00";
    NSDate *date = [df dateFromString:testDateString];
    NSParameterAssert(date);
    return date;
}

+ (void) brc_setOverrideDate:(NSDate*)overrideDate {
    _customOverrideDate = overrideDate;
    if (overrideDate) {
        [[NSUserDefaults standardUserDefaults] setObject:overrideDate forKey:@"BRCMockDateValue"];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"BRCMockDateValue"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSDate*) brc_currentOverrideDate {
    if (_customOverrideDate) {
        return _customOverrideDate;
    }
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"BRCMockDateValue"];
}

+ (void) brc_clearOverrideDate {
    _customOverrideDate = nil;
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"BRCMockDateValue"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end
