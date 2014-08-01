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



@end
