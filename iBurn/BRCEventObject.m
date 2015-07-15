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
#import "NSDateFormatter+iBurn.h"
#import "BRCDatabaseManager.h"

NSString * const kBRCStartDate2015Key = @"kBRCStartDate2015Key";
NSString * const kBRCEndDate2015Key = @"kBRCEndDate2015Key";
NSString * const kBRCMajorEvents2015Key = @"kBRCMajorEvents2015Key";

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

- (NSTimeInterval)timeIntervalForDuration {
    NSTimeInterval duration = [self.endDate timeIntervalSinceDate:self.startDate];
    return duration;
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
                               NSStringFromSelector(@selector(hostedByCampUniqueID)): @"hosted_by_camp.id",
                               NSStringFromSelector(@selector(hostedByArtUniqueID)): @"located_at_art.id",
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
    return [MTLValueTransformer transformerUsingForwardBlock:^NSString*(NSNumber* number, BOOL *success, NSError *__autoreleasing *error) {
        return number.stringValue;
    }];
}

+ (NSValueTransformer *)hostedByArtUniqueIDJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^NSString*(NSNumber* number, BOOL *success, NSError *__autoreleasing *error) {
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
    return [[NSUserDefaults standardUserDefaults] objectForKey:kBRCStartDate2015Key];
}
+ (NSDate*) festivalEndDate {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kBRCEndDate2015Key];
}
/** Array of titles of major events, starting with first day of events */
+ (NSArray*) majorEvents {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kBRCMajorEvents2015Key];
}

+ (NSArray*) datesOfFestival {
    NSCalendar *gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
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

- (UIImage *)markerImageForEventStatus
{
    if (self.isStartingSoon) {
        return [UIImage imageNamed:@"BRCLightGreenPin"];
    }
    if (self.isEndingSoon) {
        return [UIImage imageNamed:@"BRCOrangePin"];
    }
    if (self.hasEnded) {
        return [UIImage imageNamed:@"BRCRedPin"];
    }
    if (self.isHappeningRightNow) {
        return [UIImage imageNamed:@"BRCGreenPin"];
    }
    return [UIImage imageNamed:@"BRCPurplePin"];
}

- (UIColor*) colorForEventStatus {
    if (self.isStartingSoon) {
        return [UIColor brc_lightGreenColor];
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
            return @"🔨 Workshop";
            break;
        case BRCEventTypePerformance:
            return @"💃 Performance";
            break;
        case BRCEventTypeSupport:
            return @"🏥 Support";
            break;
        case BRCEventTypeParty:
            return @"🍺 Party";
            break;
        case BRCEventTypeCeremony:
            return @"🌜Ceremony";
            break;
        case BRCEventTypeGame:
            return @"🎲 Game";
            break;
        case BRCEventTypeFire:
            return @"🔥 Fire";
            break;
        case BRCEventTypeAdult:
            return @"💋 Adult";
            break;
        case BRCEventTypeKid:
            return @"👨‍👩‍👧‍👦 Kid";
            break;
        case BRCEventTypeParade:
            return @"🎉 Parade";
            break;
        case BRCEventTypeFood:
            return @"🍔 Food";
            break;
        default:
            return @"";
            break;
    }
}

+ (void) scheduleNotificationForEvent:(BRCEventObject*)eventObject transaction:(YapDatabaseReadWriteTransaction*)transaction {
    NSParameterAssert(eventObject.isFavorite);
    if ([eventObject hasStarted] || [eventObject hasEnded]) {
        return;
    }
    if (!eventObject.scheduledNotification) {
        // remind us 30 minutes before
        NSDate *reminderDate = [eventObject.startDate dateByAddingTimeInterval:-30 * 60];
        //NSDate *testingReminderDate = [[NSDate date] dateByAddingTimeInterval:10];
        NSString *startTimeString = [[NSDateFormatter brc_timeOnlyDateFormatter] stringFromDate:eventObject.startDate];
        NSString *reminderTitle = [NSString stringWithFormat:@"%@ - %@", startTimeString, eventObject.title];
        UILocalNotification *eventNotification = [[UILocalNotification alloc] init];
        eventNotification.fireDate = reminderDate;
        eventNotification.alertBody = reminderTitle;
        eventNotification.soundName = UILocalNotificationDefaultSoundName;
        eventNotification.alertAction = @"View Event";
        eventNotification.applicationIconBadgeNumber = 1;
        NSString *key = [self localNotificationUserInfoKey];
        eventNotification.userInfo = @{key: eventObject.uniqueID};
        eventObject.scheduledNotification = eventNotification;
        [transaction setObject:eventObject forKey:eventObject.uniqueID inCollection:[BRCEventObject collection]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] scheduleLocalNotification:eventNotification];
        });
    }
}

+ (NSString*) localNotificationUserInfoKey {
    NSString *key = [NSString stringWithFormat:@"%@-%@", NSStringFromClass([self class]), NSStringFromSelector(@selector(uniqueID))];
    return key;
}

+ (void) cancelScheduledNotificationForEvent:(BRCEventObject*)eventObject transaction:(YapDatabaseReadWriteTransaction*)transaction {
    NSParameterAssert(!eventObject.isFavorite);
    if (eventObject.scheduledNotification) {
        UILocalNotification *notificationToCancel = eventObject.scheduledNotification;
        eventObject.scheduledNotification = nil;
        [transaction setObject:eventObject forKey:eventObject.uniqueID inCollection:[BRCEventObject collection]];
        dispatch_async(dispatch_get_main_queue(), ^{
            [[UIApplication sharedApplication] cancelLocalNotification:notificationToCancel];
        });
    }
}

- (BRCArtObject*) hostedByArtWithTransaction:(YapDatabaseReadTransaction*)readTransaction {
    if (!self.hostedByArtUniqueID) {
        return nil;
    }
    BRCArtObject *artObject = [readTransaction objectForKey:self.hostedByArtUniqueID inCollection:[BRCArtObject collection]];
    return artObject;
}

- (BRCCampObject*) hostedByCampWithTransaction:(YapDatabaseReadTransaction*)readTransaction {
    if (!self.hostedByCampUniqueID) {
        return nil;
    }
    BRCCampObject *campObject = [readTransaction objectForKey:self.hostedByCampUniqueID inCollection:[BRCCampObject collection]];
    return campObject;
}

@end