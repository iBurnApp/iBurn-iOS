//
//  BRCArtObject.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCArtObject.h"
#import "NSDictionary+MTLManipulationAdditions.h"
#import "NSValueTransformer+MTLPredefinedTransformerAdditions.h"

@implementation BRCArtObject

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSDictionary *paths = [super JSONKeyPathsByPropertyKey];
    NSDictionary *artPaths = @{NSStringFromSelector(@selector(artistName)): @"artist",
             NSStringFromSelector(@selector(artistLocation)): @"artist_location",
             NSStringFromSelector(@selector(imageURL)): @"image_url"};
    return [paths mtl_dictionaryByAddingEntriesFromDictionary:artPaths];
}

+ (NSValueTransformer *)imageURLJSONTransformer {
    return [NSValueTransformer valueTransformerForName:MTLURLValueTransformerName];
}

@end
