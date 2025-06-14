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
    return [MTLValueTransformer transformerUsingForwardBlock:^NSDate*(NSString* dateString, BOOL *success, NSError *__autoreleasing *error) {
        if (![dateString isKindOfClass:[NSString class]] || dateString.length == 0) {
            *success = YES; // Allow nil dates
            return nil;
        }
        return [[NSDateFormatter brc_iso8601DateFormatter] dateFromString:dateString];
    }];
}

+ (NSValueTransformer *)startDateJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^NSDate*(NSString* dateString, BOOL *success, NSError *__autoreleasing *error) {
        if (![dateString isKindOfClass:[NSString class]] || dateString.length == 0) {
            *success = YES; // Allow nil dates
            return nil;
        }
        return [[NSDateFormatter brc_iso8601DateFormatter] dateFromString:dateString];
    }];
}

+ (NSValueTransformer *)endDateJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^NSDate*(NSString* dateString, BOOL *success, NSError *__autoreleasing *error) {
        if (![dateString isKindOfClass:[NSString class]] || dateString.length == 0) {
            *success = YES; // Allow nil dates
            return nil;
        }
        return [[NSDateFormatter brc_iso8601DateFormatter] dateFromString:dateString];
    }];
}

@end
