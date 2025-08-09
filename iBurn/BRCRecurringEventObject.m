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
    return [MTLValueTransformer transformerUsingForwardBlock:^NSArray*(NSArray *occurrenceArray, BOOL *success, NSError *__autoreleasing *error) {
        NSArray *eventTimes = [MTLJSONAdapter modelsOfClass:[BRCEventTime class] fromJSONArray:occurrenceArray error:error];
        return eventTimes;
    }];
}

- (NSArray*) eventObjects {
    NSMutableArray *events = [NSMutableArray arrayWithCapacity:self.eventTimes.count];
    __block NSUInteger eventCount = 0;
    [self.eventTimes enumerateObjectsUsingBlock:^(BRCEventTime *eventTime, NSUInteger idx, BOOL *stop) {
        // Check for invalid date ranges where end is before start
        if (eventTime.endDate && eventTime.startDate && [eventTime.endDate timeIntervalSinceDate:eventTime.startDate] < 0) {
            NSLog(@"WARNING: Event '%@' has negative duration (end before start). Start: %@, End: %@. Skipping this occurrence.", 
                  self.title, eventTime.startDate, eventTime.endDate);
            // Skip this invalid occurrence
            return;
        }
        
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
                NSParameterAssert(event.startDate != nil);
                NSParameterAssert(event.endDate != nil);
            }
        } else {
            BRCEventObject *event = [[BRCEventObject alloc] init];
            [event mergeValuesForKeysFromModel:self];
            event.startDate = eventTime.startDate;
            event.endDate = eventTime.endDate;
            event.uniqueID = [NSString stringWithFormat:@"%@-%d", self.uniqueID, (int)eventCount];
            NSParameterAssert(event.startDate != nil);
            NSParameterAssert(event.endDate != nil);
            [events addObject:event];
            eventCount++;
        }
    }];
    return events;
}

@end
