//
//  NSDateFormatter+iBurn.m
//  
//
//  Created by Christopher Ballinger on 7/31/14.
//
//

#import "NSDateFormatter+iBurn.h"

static NSString * const kBRCDateFormatterKey = @"kBRCDateFormatterKey";
static NSString * const kBRCGroupDateFormatterKey = @"kBRCGroupDateFormatterKey";


@implementation NSDateFormatter (iBurn)

+ (NSDateFormatter*) brc_threadSafeDateFormatter
{
    NSMutableDictionary *currentThreadStorage = [[NSThread currentThread] threadDictionary];
    NSDateFormatter *sharedDateFormatter = currentThreadStorage[kBRCDateFormatterKey];
    if (!sharedDateFormatter) {
        sharedDateFormatter = [NSDateFormatter new];
        sharedDateFormatter.dateFormat = @"yyyy-MM-dd' 'HH:mm:ss";
        sharedDateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"PST"]; //use Gerlach time
        currentThreadStorage[kBRCDateFormatterKey] = sharedDateFormatter;
    }
    
    return sharedDateFormatter;
}

+ (NSDateFormatter*) brc_threadSafeGroupDateFormatter
{
    NSMutableDictionary *currentThreadStorage = [[NSThread currentThread] threadDictionary];
    NSDateFormatter *sharedDateFormatter = currentThreadStorage[kBRCGroupDateFormatterKey];
    if (!sharedDateFormatter) {
        sharedDateFormatter = [NSDateFormatter new];
        sharedDateFormatter.dateFormat = @"yyyy-MM-dd";
        sharedDateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"PST"]; //use Gerlach time
        currentThreadStorage[kBRCGroupDateFormatterKey] = sharedDateFormatter;
    }
    
    return sharedDateFormatter;
}

+ (NSDateFormatter*) brc_timeOnlyDateFormatter {
    static NSDateFormatter *brc_timeOnlyDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        brc_timeOnlyDateFormatter = [[NSDateFormatter alloc] init];
        brc_timeOnlyDateFormatter.dateFormat = @"h:mm a";
        brc_timeOnlyDateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"PST"]; //use Gerlach time
    });
    return brc_timeOnlyDateFormatter;
}

+ (NSDateFormatter*) brc_dayOfWeekDateFormatter {
    static NSDateFormatter *brc_dayOfWeekDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        brc_dayOfWeekDateFormatter = [[NSDateFormatter alloc] init];
        brc_dayOfWeekDateFormatter.dateFormat = @"EEEE";
        brc_dayOfWeekDateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"PST"]; //use Gerlach time
    });
    return brc_dayOfWeekDateFormatter;
}

+ (NSDateFormatter*) brc_shortDateFormatter {
    static NSDateFormatter *brc_shortDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        brc_shortDateFormatter = [[NSDateFormatter alloc] init];
        brc_shortDateFormatter.dateFormat = @"M/d";
        brc_shortDateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"PST"]; //use Gerlach time
    });
    return brc_shortDateFormatter;
}

@end
