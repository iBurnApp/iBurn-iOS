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
    NSString *testDateString = @"2026-09-04T11:00:00-07:00";
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
