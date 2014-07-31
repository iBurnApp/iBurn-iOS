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
#import "BRCEventObject_Private.h"

NSString * const kBRCStartDateKey = @"kBRCStartDateKey";
NSString * const kBRCEndDateKey = @"kBRCEndDateKey";
NSString * const kBRCMajorEventsKey = @"kBRCMajorEventsKey";

@interface BRCEventObject()
@end

@implementation BRCEventObject

- (NSTimeInterval)timeIntervalUntilStartDate
{
    if (self.startDate) {
        return [self.startDate timeIntervalSinceDate:[NSDate date]];
    }
    return DBL_MAX;
}
- (NSTimeInterval)timeIntervalUntilEndDate
{
    if (self.endDate) {
        return [self.endDate timeIntervalSinceDate:[NSDate date]];
    }
    return DBL_MAX;
}
- (BOOL)isOngoing
{
    if ([self timeIntervalUntilStartDate] < 0 && [self timeIntervalUntilEndDate] > 0) {
        return YES;
    }
    return NO;
}

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSDictionary *paths = [super JSONKeyPathsByPropertyKey];
    NSDictionary *artPaths = @{NSStringFromSelector(@selector(title)): @"title",
                               NSStringFromSelector(@selector(checkLocation)): @"check_location",
                               NSStringFromSelector(@selector(otherLocation)): @"other_location",
                               NSStringFromSelector(@selector(hostedByCampUniqueID)): @"hosted_by_camp.id",
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

+ (NSValueTransformer *)hostedByCampUniqueIDJSONTransformer {
    return [MTLValueTransformer transformerWithBlock:^NSString*(NSNumber* number) {
        return number.stringValue;
    }];
}

- (BOOL) isEndingSoon {
    NSTimeInterval endingSoonTimeThreshold = 15 * 60; // 15 minutes
    // event will end soon
    NSTimeInterval timeIntervalUntilEventEnds = [self timeIntervalUntilEndDate];
    if (timeIntervalUntilEventEnds < endingSoonTimeThreshold) { // event ending soon
        return YES;
    }
    return NO;
}

/**
 *  Whether or not the event starts within the next hour
 */
- (BOOL)isStartingSoon {
    NSTimeInterval startingSoonTimeThreshold = 60 * 60; // one hour
    // event will end soon
    NSTimeInterval timeIntervalUntilEventStarts = [self timeIntervalUntilStartDate];
    if (timeIntervalUntilEventStarts < 0 && fabs(timeIntervalUntilEventStarts) < startingSoonTimeThreshold) { // event starting soon
        return YES;
    }
    return NO;
}

+ (NSDate*) festivalStartDate {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kBRCStartDateKey];
}
+ (NSDate*) festivalEndDate {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kBRCEndDateKey];
}
/** Array of titles of major events, starting with first day of events */
+ (NSArray*) majorEvents {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kBRCMajorEventsKey];
}

@end
