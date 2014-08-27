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
#import "NSDate+iBurn.h"
#import "NSDate+CupertinoYankee.h"

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
    __block NSUInteger eventCount = 0;
    [self.eventTimes enumerateObjectsUsingBlock:^(BRCEventTime *eventTime, NSUInteger idx, BOOL *stop) {
        NSInteger daysBetweenDates = [NSDate brc_daysBetweenDate:eventTime.startDate andDate:eventTime.endDate];
        // Why is the PlayaEvents API returning this?
        if (daysBetweenDates > 0) {
            NSLog(@"Duped dates for %@: %@", self.title, self.uniqueID);
            NSDate *newStartDate = eventTime.startDate;
            NSDate *newEndDate = [eventTime.startDate endOfDay];
            while ([NSDate brc_daysBetweenDate:newStartDate andDate:eventTime.endDate] >= 0 && ![newStartDate isEqualToDate:newEndDate]) {
                BRCEventObject *event = [[BRCEventObject alloc] init];
                [event mergeValuesForKeysFromModel:self];
                event.startDate = [newStartDate copy];
                event.endDate = [newEndDate copy];
                event.uniqueID = [NSString stringWithFormat:@"%@-%d", self.uniqueID, (int)eventCount];
                [events addObject:event];
                eventCount++;
                newStartDate = [[newStartDate brc_nextDay] beginningOfDay];
                if ([NSDate brc_daysBetweenDate:newStartDate andDate:eventTime.endDate] > 0) {
                    newEndDate = [newStartDate endOfDay];
                } else {
                    newEndDate = eventTime.endDate;
                }
            }
        } else {
            BRCEventObject *event = [[BRCEventObject alloc] init];
            [event mergeValuesForKeysFromModel:self];
            event.startDate = eventTime.startDate;
            event.endDate = eventTime.endDate;
            event.uniqueID = [NSString stringWithFormat:@"%@-%d", self.uniqueID, (int)eventCount];
            [events addObject:event];
            eventCount++;
        }
    }];
    return events;
}

@end
