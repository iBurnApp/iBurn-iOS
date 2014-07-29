//
//  BRCEventTime.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCEventTime.h"
#import "MTLValueTransformer.h"

@implementation BRCEventTime

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSDictionary *paths = @{NSStringFromSelector(@selector(startDate)): @"start_time",
                            NSStringFromSelector(@selector(endDate)): @"end_time"};
    return paths;
}

+ (NSDateFormatter *)dateFormatter {
    static NSDateFormatter *dateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dateFormatter = [[NSDateFormatter alloc] init];
        dateFormatter.dateFormat = @"yyyy-MM-dd' 'HH:mm:ss";
        dateFormatter.timeZone = [NSTimeZone timeZoneWithName:@"PST"]; //use Gerlach time
    });
    return dateFormatter;
}

+ (NSValueTransformer *)uniqueIDJSONTransformer {
    return [MTLValueTransformer transformerWithBlock:^NSDate*(NSString* dateString) {
        return [[self dateFormatter] dateFromString:dateString];
    }];
}

@end
