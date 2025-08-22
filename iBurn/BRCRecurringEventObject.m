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
#import "iBurn-Swift.h"

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
    
    // Get festival date range
    NSDate *festivalStart = YearSettings.eventStart;
    NSDate *festivalEnd = YearSettings.eventEnd;
    
    [self.eventTimes enumerateObjectsUsingBlock:^(BRCEventTime *eventTime, NSUInteger idx, BOOL *stop) {
        NSDate *startDate = eventTime.startDate;
        NSDate *endDate = eventTime.endDate;
        
        // Skip if dates are nil
        if (!startDate || !endDate) {
            NSLog(@"WARNING: Event '%@' has nil dates. Skipping.", self.title);
            return;
        }
        
        // Check if end is before start (negative duration)  
        if ([endDate timeIntervalSinceDate:startDate] < 0) {
            NSCalendar *calendar = [NSCalendar currentCalendar];
            
            // Extract time components from end date
            NSDateComponents *endTimeComponents = [calendar components:(NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond) fromDate:endDate];
            
            // Apply end time to start date
            NSDateComponents *startDateComponents = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:startDate];
            startDateComponents.hour = endTimeComponents.hour;
            startDateComponents.minute = endTimeComponents.minute;
            startDateComponents.second = endTimeComponents.second;
            
            NSDate *correctedEndDate = [calendar dateFromComponents:startDateComponents];
            
            // If end time is still before start time (same day), it must cross midnight
            if ([correctedEndDate timeIntervalSinceDate:startDate] <= 0) {
                correctedEndDate = [calendar dateByAddingUnit:NSCalendarUnitDay value:1 toDate:correctedEndDate options:0];
            }
            
            NSLog(@"Fixed event '%@': Start %@ -> End %@ (was %@)", 
                  self.title, startDate, correctedEndDate, endDate);
            endDate = correctedEndDate;
        }
        
        NSInteger daysBetweenDates = [NSDate brc_daysBetweenDate:startDate andDate:endDate];
        // Why is the PlayaEvents API returning this?
        if (daysBetweenDates > 0) {
            NSLog(@"Duped dates for %@: %@", self.title, self.uniqueID);
            NSDate *newStartDate = startDate;
            NSDate *newEndDate = [startDate endOfDay];
            while ([NSDate brc_daysBetweenDate:newStartDate andDate:endDate] >= 0 && ![newStartDate isEqualToDate:newEndDate]) {
                // Validate each split day event against festival dates
                BOOL startInRange = ([newStartDate compare:festivalStart] != NSOrderedAscending && 
                                     [newStartDate compare:festivalEnd] != NSOrderedDescending);
                BOOL endInRange = ([newEndDate compare:festivalStart] != NSOrderedAscending && 
                                   [newEndDate compare:festivalEnd] != NSOrderedDescending);
                
                if (startInRange && endInRange) {
                    BRCEventObject *event = [[BRCEventObject alloc] init];
                    [event mergeValuesForKeysFromModel:self];
                    event.startDate = [newStartDate copy];
                    event.endDate = [newEndDate copy];
                    event.uniqueID = [NSString stringWithFormat:@"%@-%d", self.uniqueID, (int)eventCount];
                    
                    // Mark events over 12 hours as all-day
                    NSTimeInterval duration = [newEndDate timeIntervalSinceDate:newStartDate];
                    if (duration >= (12 * 60 * 60)) { // 12 hours in seconds
                        event.isAllDay = YES;
                        NSLog(@"Marking split event '%@' as all-day (duration: %.1fh)", self.title, duration / 3600.0);
                    }
                    
                    [events addObject:event];
                    eventCount++;
                } else {
                    NSLog(@"Skipping split event '%@' outside festival dates. Start: %@, End: %@", 
                          self.title, newStartDate, newEndDate);
                }
                
                newStartDate = [[newStartDate brc_nextDay] beginningOfDay];
                if ([NSDate brc_daysBetweenDate:newStartDate andDate:endDate] > 0) {
                    newEndDate = [newStartDate endOfDay];
                } else {
                    newEndDate = endDate;
                }
            }
        } else {
            // Single day event - validate against festival dates
            BOOL startInRange = ([startDate compare:festivalStart] != NSOrderedAscending && 
                                 [startDate compare:festivalEnd] != NSOrderedDescending);
            BOOL endInRange = ([endDate compare:festivalStart] != NSOrderedAscending && 
                               [endDate compare:festivalEnd] != NSOrderedDescending);
            
            if (startInRange && endInRange) {
                BRCEventObject *event = [[BRCEventObject alloc] init];
                [event mergeValuesForKeysFromModel:self];
                event.startDate = startDate;
                event.endDate = endDate;
                event.uniqueID = [NSString stringWithFormat:@"%@-%d", self.uniqueID, (int)eventCount];
                
                // Mark events over 12 hours as all-day
                NSTimeInterval duration = [endDate timeIntervalSinceDate:startDate];
                if (duration >= (12 * 60 * 60)) { // 12 hours in seconds
                    event.isAllDay = YES;
                    NSLog(@"Marking event '%@' as all-day (duration: %.1fh)", self.title, duration / 3600.0);
                }
                
                NSParameterAssert(event.startDate != nil);
                NSParameterAssert(event.endDate != nil);
                [events addObject:event];
                eventCount++;
            } else {
                NSLog(@"WARNING: Event '%@' falls outside festival dates. Start: %@, End: %@. Skipping.",
                      self.title, startDate, endDate);
            }
        }
    }];
    return events;
}

@end
