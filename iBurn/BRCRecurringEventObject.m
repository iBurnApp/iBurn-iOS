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
        // We'll handle date swapping when creating the event objects below
        NSDate *startDate = eventTime.startDate;
        NSDate *endDate = eventTime.endDate;
        
        // Check for invalid date ranges where end is before start
        if (endDate && startDate && [endDate timeIntervalSinceDate:startDate] < 0) {
            NSTimeInterval duration = [endDate timeIntervalSinceDate:startDate];
            NSTimeInterval hoursDiff = duration / 3600.0;
            
            // Always swap the dates when end is before start
            NSLog(@"WARNING: Event '%@' has negative duration (%.1fh). Swapping dates. Original: %@ to %@",
                  self.title, hoursDiff, eventTime.startDate, eventTime.endDate);
            NSDate *tempDate = startDate;
            startDate = endDate;
            endDate = tempDate;
        }
        
        NSInteger daysBetweenDates = [NSDate brc_daysBetweenDate:startDate andDate:endDate];
        // Why is the PlayaEvents API returning this?
        if (daysBetweenDates > 0) {
            NSLog(@"Duped dates for %@: %@", self.title, self.uniqueID);
            NSDate *newStartDate = startDate;
            NSDate *newEndDate = [startDate endOfDay];
            while ([NSDate brc_daysBetweenDate:newStartDate andDate:endDate] >= 0 && ![newStartDate isEqualToDate:newEndDate]) {
                BRCEventObject *event = [[BRCEventObject alloc] init];
                [event mergeValuesForKeysFromModel:self];
                event.startDate = [newStartDate copy];
                event.endDate = [newEndDate copy];
                event.uniqueID = [NSString stringWithFormat:@"%@-%d", self.uniqueID, (int)eventCount];
                [events addObject:event];
                eventCount++;
                newStartDate = [[newStartDate brc_nextDay] beginningOfDay];
                if ([NSDate brc_daysBetweenDate:newStartDate andDate:endDate] > 0) {
                    newEndDate = [newStartDate endOfDay];
                } else {
                    newEndDate = endDate;
                }
                NSParameterAssert(event.startDate != nil);
                NSParameterAssert(event.endDate != nil);
            }
        } else {
            BRCEventObject *event = [[BRCEventObject alloc] init];
            [event mergeValuesForKeysFromModel:self];
            event.startDate = startDate;
            event.endDate = endDate;
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
