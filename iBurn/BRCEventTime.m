//
//  BRCEventTime.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCEventTime.h"
#import "MTLValueTransformer.h"
#import "NSDateFormatter+iBurn.h"

@implementation BRCEventTime

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSDictionary *paths = @{NSStringFromSelector(@selector(startDate)): @"start_time",
                            NSStringFromSelector(@selector(endDate)): @"end_time"};
    return paths;
}

+ (NSValueTransformer *)uniqueIDJSONTransformer {
    return [MTLValueTransformer transformerWithBlock:^NSDate*(NSString* dateString) {
        return [[NSDateFormatter brc_threadSafeDateFormatter] dateFromString:dateString];
    }];
}

+ (NSValueTransformer *)startDateJSONTransformer {
    return [MTLValueTransformer transformerWithBlock:^NSDate*(NSString* dateString) {
        return [[NSDateFormatter brc_threadSafeDateFormatter] dateFromString:dateString];
    }];
}

+ (NSValueTransformer *)endDateJSONTransformer {
    return [MTLValueTransformer transformerWithBlock:^NSDate*(NSString* dateString) {
        return [[NSDateFormatter brc_threadSafeDateFormatter] dateFromString:dateString];
    }];
}

@end
