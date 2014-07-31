//
//  NSDateFormatter+iBurn.m
//  
//
//  Created by Christopher Ballinger on 7/31/14.
//
//

#import "NSDateFormatter+iBurn.h"

static NSString * const kBRCNSDateFormatterKey = @"kBRCNSDateFormatterKey";

@implementation NSDateFormatter (iBurn)

+ (NSDateFormatter*) brc_threadSafeDateFormatter
{
    NSMutableDictionary *currentThreadStorage = [[NSThread currentThread] threadDictionary];
    NSDateFormatter *sharedDateFormatter = currentThreadStorage[kBRCNSDateFormatterKey];
    if (!sharedDateFormatter) {
        sharedDateFormatter = [NSDateFormatter new];
        sharedDateFormatter.dateFormat = @"yyyy-MM-dd' 'HH:mm:ss";
        sharedDateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"PST"]; //use Gerlach time
        currentThreadStorage[kBRCNSDateFormatterKey] = sharedDateFormatter;
    }
    
    return sharedDateFormatter;
}

@end
