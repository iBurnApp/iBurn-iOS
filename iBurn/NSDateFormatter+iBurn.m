//
//  NSDateFormatter+iBurn.m
//  
//
//  Created by Christopher Ballinger on 7/31/14.
//
//

#import "NSDateFormatter+iBurn.h"
#import "iBurn-Swift.h"

@implementation NSDateFormatter (iBurn)

+ (NSDateFormatter*) brc_playaEventsAPIDateFormatter
{
    static NSDateFormatter *brc_playaEventsAPIDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        brc_playaEventsAPIDateFormatter = [NSDateFormatter new];
        brc_playaEventsAPIDateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZZZZZ";
        brc_playaEventsAPIDateFormatter.timeZone = [NSTimeZone brc_burningManTimeZone];
    });
    return brc_playaEventsAPIDateFormatter;
}

+ (NSDateFormatter*) brc_eventGroupDateFormatter
{
    return DateFormatters.eventGroupDateFormatter;
}

/** e.g. 2015-09-04 11 */
+ (NSDateFormatter*) brc_eventGroupHourlyDateFormatter {
    static NSDateFormatter *brc_eventGroupDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        brc_eventGroupDateFormatter = [NSDateFormatter new];
        brc_eventGroupDateFormatter.dateFormat = @"yyyy-MM-dd' 'HH";
        brc_eventGroupDateFormatter.timeZone = [NSTimeZone brc_burningManTimeZone];
    });
    return brc_eventGroupDateFormatter;
}

+ (NSDateFormatter*) brc_timeOnlyDateFormatter {
    return DateFormatters.timeOnly;
}

+ (NSDateFormatter*) brc_dayOfWeekDateFormatter {
    return DateFormatters.dayOfWeek;
}

+ (NSDateFormatter*) brc_shortDateFormatter {
    static NSDateFormatter *brc_shortDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        brc_shortDateFormatter = [[NSDateFormatter alloc] init];
        brc_shortDateFormatter.dateFormat = @"M/d";
        brc_shortDateFormatter.timeZone = [NSTimeZone brc_burningManTimeZone];
    });
    return brc_shortDateFormatter;
}

@end
