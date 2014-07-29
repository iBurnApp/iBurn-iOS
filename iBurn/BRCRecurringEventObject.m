//
//  BRCRecurringEventObject.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCRecurringEventObject.h"
#import "NSDictionary+MTLManipulationAdditions.h"
#import "MTLValueTransformer.h"
#import "BRCEventTime.h"
#import "BRCEventObject_Private.h"
#import "BRCDataObject_Private.h"

@implementation BRCRecurringEventObject

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSDictionary *paths = [super JSONKeyPathsByPropertyKey];
    NSDictionary *artPaths = @{NSStringFromSelector(@selector(eventTimes)): @"occurrence_set"};
    return [paths mtl_dictionaryByAddingEntriesFromDictionary:artPaths];
}

+ (NSValueTransformer *)eventTimesJSONTransformer {
    return [MTLValueTransformer transformerWithBlock:^NSArray*(NSArray *occurrenceArray) {
        NSError *error = nil;
        NSArray *eventTimes = [MTLJSONAdapter modelsOfClass:[BRCEventTime class] fromJSONArray:occurrenceArray error:&error];
        return eventTimes;
    }];
}

- (NSArray*) eventObjects {
    NSMutableArray *events = [NSMutableArray arrayWithCapacity:self.eventTimes.count];
    [self.eventTimes enumerateObjectsUsingBlock:^(BRCEventTime *eventTime, NSUInteger idx, BOOL *stop) {
        BRCEventObject *event = [[BRCEventObject alloc] init];
        [event mergeValuesForKeysFromModel:self];
        event.startDate = eventTime.startDate;
        event.endDate = eventTime.endDate;
        event.uniqueID = [NSString stringWithFormat:@"%@-%d", self.uniqueID, (int)idx];
        [events addObject:event];
    }];
    return events;
}

@end
