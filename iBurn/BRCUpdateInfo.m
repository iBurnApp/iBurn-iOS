//
//  BRCUpdateInfo.m
//  iBurn
//
//  Created by Christopher Ballinger on 6/28/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import "BRCUpdateInfo.h"
#import "NSDateFormatter+iBurn.h"

@implementation BRCUpdateInfo

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{NSStringFromSelector(@selector(file)): @"file",
             NSStringFromSelector(@selector(lastUpdated)): @"updated"};
}

+ (NSValueTransformer *)lastUpdatedJSONTransformer {
    return [MTLValueTransformer transformerWithBlock:^NSDate*(NSString* dateString) {
        return [[NSDateFormatter brc_playaEventsAPIDateFormatter] dateFromString:dateString];
    }];
}

@end
