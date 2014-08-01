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
#import "UIColor+iBurn.h"

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

- (BOOL)isHappeningRightNow
{
    if ([self hasStarted] && ![self hasEnded]) {
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
    if (timeIntervalUntilEventEnds < endingSoonTimeThreshold && timeIntervalUntilEventEnds > 0) { // event ending soon
        return YES;
    }
    return NO;
}

/**
 *  Whether or not the event starts within the next hour
 */
- (BOOL)isStartingSoon {
    NSTimeInterval startingSoonTimeThreshold = 60 * 60; // one hour
    NSTimeInterval timeIntervalUntilEventStarts = [self timeIntervalUntilStartDate];
    if (![self hasStarted] && timeIntervalUntilEventStarts < startingSoonTimeThreshold) { // event starting soon
        return YES;
    }
    return NO;
}

- (BOOL)hasStarted {
    NSTimeInterval timeIntervalUntilEventStarts = [self timeIntervalUntilStartDate];
    if (timeIntervalUntilEventStarts < 0) { // event started
        return YES;
    }
    return NO;
}

- (BOOL)hasEnded {
    NSTimeInterval timeIntervalUntilEventEnds = [self timeIntervalUntilEndDate];
    if (timeIntervalUntilEventEnds < 0) { // event ended
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

+ (NSArray*) datesOfFestival {
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDate *festivalStartDate = [self festivalStartDate];
    NSUInteger numberOfDays = [self majorEvents].count;

    NSMutableArray *dates = [NSMutableArray arrayWithCapacity:numberOfDays];
    
    for (int i = 0; i < numberOfDays; i++) {
        NSDateComponents *dayComponent = [[NSDateComponents alloc] init];
        dayComponent.day = i;
        
        NSDate *nextDate = [gregorianCalendar dateByAddingComponents:dayComponent toDate:festivalStartDate options:0];
        [dates addObject:nextDate];
    }
    return dates;
}

- (UIColor*) colorForEventStatus {
    if (self.isStartingSoon) {
        return [UIColor brc_greenColor];
    }
    if (!self.hasStarted) {
        return [UIColor darkTextColor];
    }
    if (self.isEndingSoon) {
        return [UIColor brc_orangeColor];
    }
    if (self.hasEnded) {
        return [UIColor brc_redColor];
    }
    if (self.isHappeningRightNow) {
        return [UIColor brc_greenColor];
    }
    return [UIColor darkTextColor];
}

+ (NSString *)stringForEventType:(BRCEventType)type
{
    switch (type) {
        case BRCEventTypeWorkshop:
            return @"Workshop";
            break;
        case BRCEventTypePerformance:
            return @"Performance";
            break;
        case BRCEventTypeSupport:
            return @"Support";
            break;
        case BRCEventTypeParty:
            return @"Party";
            break;
        case BRCEventTypeCeremony:
            return @"Ceremony";
            break;
        case BRCEventTypeGame:
            return @"Game";
            break;
        case BRCEventTypeFire:
            return @"Fire";
            break;
        case BRCEventTypeAdult:
            return @"Adult";
            break;
        case BRCEventTypeKid:
            return @"Kid";
            break;
        case BRCEventTypeParade:
            return @"Parade";
            break;
        case BRCEventTypeFood:
            return @"Food";
            break;
        default:
            return @"Unkown";
            break;
    }
}

@end
