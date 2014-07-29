//
//  BRCEventObject.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCEventObject.h"
#import "NSDictionary+MTLManipulationAdditions.h"
#import "NSValueTransformer+MTLPredefinedTransformerAdditions.h"
#import "MTLValueTransformer.h"

@implementation BRCEventObject

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSDictionary *paths = [super JSONKeyPathsByPropertyKey];
    NSDictionary *artPaths = @{NSStringFromSelector(@selector(title)): @"title",
                               NSStringFromSelector(@selector(times)): @"occurrence_set",
                               NSStringFromSelector(@selector(checkLocation)): @"check_location",
                               NSStringFromSelector(@selector(otherLocation)): @"other_location",
                               NSStringFromSelector(@selector(hostedByCampUniqueID)): @"hosted_by_camp",
                               NSStringFromSelector(@selector(eventType)): @"event_type.abbr",
                               NSStringFromSelector(@selector(isAllDay)): @"all_day"};
    return [paths mtl_dictionaryByAddingEntriesFromDictionary:artPaths];
}

+ (NSValueTransformer *)eventTypeJSONTransformer {
    NSDictionary *transformDict = @{@"":     @(BRCEventTypeUnknown),
                                    @"none": @(BRCEventTypeNone),
                                    @"work": @(BRCEventTypeWorkshop),
                                    @"perf": @(BRCEventTypePerformance),
                                    @"care": @(BRCEventTypeSupport),
                                    @"prty": @(BRCEventTypeParty),
                                    @"cere": @(BRCEventTypeCeremony),
                                    @"game": @(BRCEventTypeGame),
                                    @"fire": @(BRCEventTypeFire),
                                    @"adlt": @(BRCEventTypeAdult),
                                    @"kid":  @(BRCEventTypeKid),
                                    @"para": @(BRCEventTypeParade),
                                    @"food": @(BRCEventTypeFood)};
    return [NSValueTransformer mtl_valueMappingTransformerWithDictionary:transformDict];
}

@end
