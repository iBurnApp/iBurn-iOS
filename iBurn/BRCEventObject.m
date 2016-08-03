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
#import "iBurn-Swift.h"
@import EventKit;

NSString * const kBRCStartDate2016Key = @"kBRCStartDate2016Key";
NSString * const kBRCEndDate2016Key = @"kBRCEndDate2016Key";
NSString * const kBRCMajorEvents2016Key = @"kBRCMajorEvents2016Key";

NSString * const kBRCEventCampEdgeName = @"camp";
NSString * const kBRCEventArtEdgeName = @"art";


@interface BRCEventObject()
@end

@implementation BRCEventObject

- (NSTimeInterval)timeIntervalUntilStart:(NSDate*)date
{
    if (self.startDate) {
        return [self.startDate timeIntervalSinceDate:date];
    }
    return DBL_MAX;
}

- (NSTimeInterval)timeIntervalUntilEnd:(NSDate*)date
{
    if (self.endDate) {
        return [self.endDate timeIntervalSinceDate:date];
    }
    return DBL_MAX;
}

- (NSTimeInterval)timeIntervalForDuration {
    NSTimeInterval duration = [self.endDate timeIntervalSinceDate:self.startDate];
    return duration;
}

- (BOOL)isHappeningRightNow:(NSDate*)currentDate
{
    if ([self hasStarted:currentDate] && ![self hasEnded:currentDate]) {
        return YES;
    }
    return NO;
}

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSDictionary *paths = [super JSONKeyPathsByPropertyKey];
    NSDictionary *artPaths = @{NSStringFromSelector(@selector(title)): @"title",
                               NSStringFromSelector(@selector(checkLocation)): @"check_location",
                               NSStringFromSelector(@selector(hostedByCampUniqueID)): @"hosted_by_camp",
                               NSStringFromSelector(@selector(hostedByArtUniqueID)): @"located_at_art",
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

- (BOOL) isEndingSoon:(NSDate*)currentDate {
    NSTimeInterval endingSoonTimeThreshold = 15 * 60; // 15 minutes
    // event will end soon
    NSTimeInterval timeIntervalUntilEventEnds = [self timeIntervalUntilEnd:currentDate];
    if (timeIntervalUntilEventEnds < endingSoonTimeThreshold && timeIntervalUntilEventEnds > 0) { // event ending soon
        return YES;
    }
    return NO;
}

/**
 *  Whether or not the event starts within the next hour
 */
- (BOOL)isStartingSoon:(NSDate*)currentDate {
    NSTimeInterval startingSoonTimeThreshold = 60 * 60; // one hour
    NSTimeInterval timeIntervalUntilEventStarts = [self timeIntervalUntilStart:currentDate];
    if (![self hasStarted:currentDate] && timeIntervalUntilEventStarts < startingSoonTimeThreshold) { // event starting soon
        return YES;
    }
    return NO;
}

- (BOOL)hasStarted:(NSDate*)currentDate {
    NSTimeInterval timeIntervalUntilEventStarts = [self timeIntervalUntilStart:currentDate];
    if (timeIntervalUntilEventStarts < 0) { // event started
        return YES;
    }
    return NO;
}

- (BOOL)hasEnded:(NSDate*)currentDate {
    NSTimeInterval timeIntervalUntilEventEnds = [self timeIntervalUntilEnd:currentDate];
    if (timeIntervalUntilEventEnds < 0) { // event ended
        return YES;
    }
    return NO;
}

+ (NSDate*) festivalStartDate {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kBRCStartDate2016Key];
}
+ (NSDate*) festivalEndDate {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kBRCEndDate2016Key];
}
/** Array of titles of major events, starting with first day of events */
+ (NSArray*) majorEvents {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kBRCMajorEvents2016Key];
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

- (UIImage *)markerImageForEventStatus:(NSDate*)currentDate
{
    if ([self isStartingSoon:currentDate]) {
        return [UIImage imageNamed:@"BRCLightGreenPin"];
    }
    if ([self isEndingSoon:currentDate]) {
        return [UIImage imageNamed:@"BRCOrangePin"];
    }
    if ([self hasEnded:currentDate]) {
        return [UIImage imageNamed:@"BRCRedPin"];
    }
    if ([self isHappeningRightNow:currentDate]) {
        return [UIImage imageNamed:@"BRCGreenPin"];
    }
    return [UIImage imageNamed:@"BRCPurplePin"];
}

- (UIColor*) colorForEventStatus:(NSDate*)currentDate {
    if ([self isStartingSoon:currentDate]) {
        return [UIColor brc_lightGreenColor];
    }
    if (![self hasStarted:currentDate]) {
        return [UIColor darkTextColor];
    }
    if ([self isEndingSoon:currentDate]) {
        return [UIColor brc_orangeColor];
    }
    if ([self hasEnded:currentDate]) {
        return [UIColor brc_redColor];
    }
    if ([self isHappeningRightNow:currentDate]) {
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

+ (EKEventStore*)eventStore {
    EKEventStore *store = [[EKEventStore alloc] init];
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
    if (status != EKAuthorizationStatusAuthorized) {
        NSLog(@"Not authorized to modify calendar");
        dispatch_async(dispatch_get_main_queue(), ^{
            [BRCPermissions promptForEvents:^{
                
            }];
        });
        return nil;
    }
    return store;
}

- (BRCDataObject*) hostWithTransaction:(YapDatabaseReadTransaction*)readTransaction {
    BRCDataObject *host = [self hostedByCampWithTransaction:readTransaction];
    if (!host) {
        host = [self hostedByArtWithTransaction:readTransaction];
    }
    return host;
}


+ (void) scheduleNotificationForEvent:(BRCEventObject*)eventObject transaction:(YapDatabaseReadWriteTransaction*)transaction {
    NSParameterAssert(eventObject.isFavorite);
    EKEventStore *store = [self eventStore];
    if (!store) {
        return;
    }
    if (eventObject.calendarEventIdentifier) {
        EKEvent *existingEvent = [store eventWithIdentifier:eventObject.calendarEventIdentifier];
        if (existingEvent) {
            NSLog(@"Event already exists in calendar: %@ %@", eventObject, existingEvent);
            return;
        }
    }
    BRCDataObject *host = [eventObject hostWithTransaction:transaction];
    NSMutableString *locationString = [NSMutableString string];
    if (host.playaLocation) {
        [locationString appendFormat:@"%@ - ", host.playaLocation];
    }
    if (host.title) {
        [locationString appendFormat:@"%@", host.title];
    }
    EKCalendar *calendar = [store defaultCalendarForNewEvents];
    EKEvent *calendarEvent = [EKEvent eventWithEventStore:store];
    calendarEvent.calendar = calendar;
    calendarEvent.title = eventObject.title;
    calendarEvent.location = locationString;
    calendarEvent.timeZone = [NSTimeZone brc_burningManTimeZone];
    calendarEvent.startDate = eventObject.startDate;
    calendarEvent.endDate = eventObject.endDate;
    calendarEvent.allDay = eventObject.isAllDay;
    calendarEvent.URL = eventObject.url;
    calendarEvent.notes = eventObject.detailDescription;
    // Remind 1.5 hrs in advance
    EKAlarm *alarm = [EKAlarm alarmWithRelativeOffset:-90 * 60];
    [calendarEvent addAlarm:alarm];
    
    NSError *error = nil;
    BOOL success = [store saveEvent:calendarEvent span:EKSpanThisEvent error:&error];
    if (!success) {
        NSLog(@"Couldn't save event: %@ %@ %@", eventObject, calendarEvent, error);
        return;
    }
    eventObject.calendarEventIdentifier = calendarEvent.eventIdentifier;
    [transaction setObject:eventObject forKey:eventObject.uniqueID inCollection:[BRCEventObject collection]];
}

+ (NSString*) localNotificationUserInfoKey {
    NSString *key = [NSString stringWithFormat:@"%@-%@", NSStringFromClass([self class]), NSStringFromSelector(@selector(uniqueID))];
    return key;
}

+ (void) cancelScheduledNotificationForEvent:(BRCEventObject*)eventObject transaction:(YapDatabaseReadWriteTransaction*)transaction {
    NSParameterAssert(!eventObject.isFavorite);
    EKEventStore *store = [self eventStore];
    if (!store) {
        return;
    }
    if (eventObject.calendarEventIdentifier) {
        EKEvent *existingEvent = [store eventWithIdentifier:eventObject.calendarEventIdentifier];
        if (existingEvent) {
            NSError *error = nil;
            BOOL success = [store removeEvent:existingEvent span:EKSpanThisEvent error:&error];
            if (!success) {
                NSLog(@"Couldn't remove event: %@ %@ %@", eventObject, existingEvent, error);
            }
        }
    }
    eventObject.calendarEventIdentifier = nil;
    [transaction setObject:eventObject forKey:eventObject.uniqueID inCollection:[BRCEventObject collection]];
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

#pragma mark YapDatabaseRelationshipNode

// This method gets automatically called when the object is inserted/updated in the database.
- (NSArray *)yapDatabaseRelationshipEdges
{
    NSMutableArray *edges = [NSMutableArray arrayWithCapacity:2];
    
    YapDatabaseRelationshipEdge *campEdge =
    [YapDatabaseRelationshipEdge edgeWithName:kBRCEventCampEdgeName
                               destinationKey:self.hostedByCampUniqueID
                                   collection:[[BRCCampObject class] collection]
                              nodeDeleteRules:YDB_NotifyIfSourceDeleted | YDB_NotifyIfDestinationDeleted];
    if (campEdge) {
        [edges addObject:campEdge];
    }
    
    YapDatabaseRelationshipEdge *artEdge =
    [YapDatabaseRelationshipEdge edgeWithName:kBRCEventArtEdgeName
                               destinationKey:self.hostedByArtUniqueID
                                   collection:[[BRCArtObject class] collection]
                              nodeDeleteRules:YDB_NotifyIfSourceDeleted | YDB_NotifyIfDestinationDeleted];
    
    if (artEdge) {
        [edges addObject:artEdge];
    }
    
    return edges;
}

@end