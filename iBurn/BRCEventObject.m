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
#import "BRCDataObject_Private.h"
#import "UIColor+iBurn.h"
#import "NSDateFormatter+iBurn.h"
#import "BRCDatabaseManager.h"
#import "iBurn-Swift.h"
@import EventKit;

NSString * const kBRCEventCampEdgeName = @"camp";
NSString * const kBRCEventArtEdgeName = @"art";


@interface BRCEventObject()
@end

@implementation BRCEventObject
@dynamic isAllDay;

+ (NSArray<NSString*>*) excludedPropertyKeysArray {
    NSMutableArray<NSString*> *keys = [[super excludedPropertyKeysArray] mutableCopy];
    [keys addObject:NSStringFromSelector(@selector(isAllDay))];
    return keys;
}


/** The API no longer has all_day, but camps are now just listing events from 12:00am->11:45pm which is bullshit */
- (BOOL) isAllDay {
    if (self.timeIntervalForDuration > 23 * 60 * 60) {
        return YES;
    }
    return NO;
}

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    NSDictionary *paths = [super JSONKeyPathsByPropertyKey];
    NSDictionary *artPaths = @{NSStringFromSelector(@selector(title)): @"title",
                               NSStringFromSelector(@selector(checkLocation)): @"check_location",
                               NSStringFromSelector(@selector(otherLocation)): @"other_location",
                               NSStringFromSelector(@selector(hostedByCampUniqueID)): @"hosted_by_camp",
                               NSStringFromSelector(@selector(hostedByArtUniqueID)): @"located_at_art",
                               NSStringFromSelector(@selector(eventType)): @"event_type.abbr"};
    return [paths mtl_dictionaryByAddingEntriesFromDictionary:artPaths];
}

+ (NSDate*) festivalStartDate {
    return YearSettings.eventStart;
}
+ (NSDate*) festivalEndDate {
    return YearSettings.eventEnd;
}
+ (NSArray<NSDate*>*) datesOfFestival {
    return YearSettings.festivalDays;
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

- (BRCDataObject*) hostWithTransaction:(YapDatabaseReadTransaction*)readTransaction {
    BRCDataObject *host = [self hostedByCampWithTransaction:readTransaction];
    if (!host) {
        host = [self hostedByArtWithTransaction:readTransaction];
    }
    return host;
}

- (void) scheduleNotification:(YapDatabaseReadWriteTransaction*)transaction metadata:(BRCEventMetadata*)metadata {
    NSParameterAssert(metadata.isFavorite);
    EKEventStore *store = [[self class] eventStore];
    if (!store) {
        return;
    }
    if (metadata.calendarEventIdentifier) {
        EKEvent *existingEvent = [store eventWithIdentifier:metadata.calendarEventIdentifier];
        if (existingEvent) {
            NSLog(@"Event already exists in calendar: %@ %@", self, existingEvent);
            return;
        }
    }
    BRCDataObject *host = [self hostWithTransaction:transaction];
    NSMutableString *locationString = [NSMutableString string];
    NSString *playaLocation = host.playaLocation;
    if (!playaLocation.length) {
        playaLocation = host.burnerMapLocationString;
    }
    if (playaLocation.length) {
        [locationString appendFormat:@"%@ - ", playaLocation];
    }
    if (host.title) {
        [locationString appendFormat:@"%@", host.title];
    }
    EKCalendar *calendar = [store defaultCalendarForNewEvents];
    EKEvent *calendarEvent = [EKEvent eventWithEventStore:store];
    calendarEvent.calendar = calendar;
    calendarEvent.title = self.title;
    calendarEvent.location = locationString;
    calendarEvent.timeZone = [NSTimeZone brc_burningManTimeZone];
    calendarEvent.startDate = self.startDate;
    calendarEvent.endDate = self.endDate;
    calendarEvent.allDay = self.isAllDay;
    calendarEvent.URL = self.url;
    calendarEvent.notes = self.detailDescription;
    // Remind 1.5 hrs in advance
    EKAlarm *alarm = [EKAlarm alarmWithRelativeOffset:-90 * 60];
    [calendarEvent addAlarm:alarm];
    // Also remind 10 min in advance
    EKAlarm *alarm2 = [EKAlarm alarmWithRelativeOffset:-10 * 60];
    [calendarEvent addAlarm:alarm2];
    
    NSError *error = nil;
    BOOL success = [store saveEvent:calendarEvent span:EKSpanThisEvent error:&error];
    if (!success) {
        NSLog(@"Couldn't save event: %@ %@ %@", self, calendarEvent, error);
        return;
    }
    metadata = [metadata copy];
    metadata.calendarEventIdentifier = calendarEvent.eventIdentifier;
    [self replaceMetadata:metadata transaction:transaction];
}

#pragma mark YapDatabaseRelationshipNode

// This method gets automatically called when the object is inserted/updated in the database.
- (NSArray *)yapDatabaseRelationshipEdges
{
    NSMutableArray *edges = [NSMutableArray arrayWithCapacity:2];
    
    if (self.hostedByCampUniqueID.length > 0) {
        YapDatabaseRelationshipEdge *campEdge =
        [YapDatabaseRelationshipEdge edgeWithName:kBRCEventCampEdgeName
                                   destinationKey:self.hostedByCampUniqueID
                                       collection:BRCCampObject.yapCollection
                                  nodeDeleteRules:YDB_NotifyIfSourceDeleted | YDB_NotifyIfDestinationDeleted];
        if (campEdge) {
            [edges addObject:campEdge];
        }
    }

    if (self.hostedByArtUniqueID.length > 0) {
        YapDatabaseRelationshipEdge *artEdge =
        [YapDatabaseRelationshipEdge edgeWithName:kBRCEventArtEdgeName
                                   destinationKey:self.hostedByArtUniqueID
                                       collection:[[BRCArtObject class] yapCollection]
                                  nodeDeleteRules:YDB_NotifyIfSourceDeleted | YDB_NotifyIfDestinationDeleted];
        
        if (artEdge) {
            [edges addObject:artEdge];
        }
    }
    
    if (edges.count == 0) {
        return nil;
    }
    
    
    return edges;
}

@end
