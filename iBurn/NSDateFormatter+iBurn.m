//
//  NSDateFormatter+iBurn.m
//
//
//  Created by Christopher Ballinger on 7/31/14.
//
//

#import "NSDateFormatter+iBurn.h"
#import "NSDate+CupertinoYankee.h" // For timeZone
#import "iBurn-Swift.h"

@implementation NSDateFormatter (iBurn)

+ (NSISO8601DateFormatter*)brc_iso8601DateFormatter {
    static NSISO8601DateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSISO8601DateFormatter alloc] init];
        // The format from API example: "2024-08-27T13:00:00-07:00"
        // NSISO8601DateFormatter handles this by default.
        // It's good practice to set formatOptions if specific variations are expected,
        // but for standard ISO8601 with timezone offset, defaults usually work.
        // formatter.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithDashSeparatorInDate | NSISO8601DateFormatWithColonSeparatorInTime;
    });
    return formatter;
}

+ (NSDateFormatter*)brc_playaEventsAPIDateFormatter {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
        formatter.timeZone = [NSTimeZone brc_burningManTimeZone];
    });
    return formatter;
}

+ (NSDateFormatter*)brc_eventGroupDateFormatter {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd";
        formatter.timeZone = [NSTimeZone brc_burningManTimeZone];
    });
    return formatter;
}

/** e.g. 2015-09-04 11 */
+ (NSDateFormatter*)brc_eventGroupHourlyDateFormatter {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH";
        formatter.timeZone = [NSTimeZone brc_burningManTimeZone];
    });
    return formatter;
}

+ (NSDateFormatter*)dayOfWeekTimeOfDay {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"EEEE HH:mm";
        formatter.timeZone = [NSTimeZone brc_burningManTimeZone];
    });
    return formatter;
}

+ (NSDateFormatter*)timeOnly {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterNoStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        formatter.timeZone = [NSTimeZone brc_burningManTimeZone];
    });
    return formatter;
}

+ (NSDateFormatter*)dayOfWeek {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"EEEE";
        formatter.timeZone = [NSTimeZone brc_burningManTimeZone];
    });
    return formatter;
}

+ (NSDateFormatter*)brc_timeOnlyDateFormatter {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterNoStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        formatter.timeZone = [NSTimeZone brc_burningManTimeZone];
    });
    return formatter;
}

+ (NSDateFormatter*)brc_dayOfWeekDateFormatter {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"EEEE";
        formatter.timeZone = [NSTimeZone brc_burningManTimeZone];
    });
    return formatter;
}

+ (NSDateFormatter*)brc_shortDateFormatter {
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"M/dd";
        formatter.timeZone = [NSTimeZone brc_burningManTimeZone];
    });
    return formatter;
}

@end
