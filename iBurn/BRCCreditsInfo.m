//
//  BRCCreditsInfo.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/9/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import "BRCCreditsInfo.h"

@implementation BRCCreditsInfo

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{NSStringFromSelector(@selector(name)): @"name",
             NSStringFromSelector(@selector(url)): @"url",
             NSStringFromSelector(@selector(blurb)): @"blurb"};
}

+ (NSValueTransformer *)urlJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

@end

