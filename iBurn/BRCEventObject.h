//
//  BRCEventObject.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataObject.h"
@import YapDatabase;
#import "BRCArtObject.h"
#import "BRCCampObject.h"

typedef NS_ENUM(NSUInteger, BRCEventType) {
    BRCEventTypeUnknown,
    BRCEventTypeNone,
    BRCEventTypeWorkshop,
    BRCEventTypePerformance,
    BRCEventTypeSupport,
    BRCEventTypeParty,
    BRCEventTypeCeremony,
    BRCEventTypeGame,
    BRCEventTypeFire,
    BRCEventTypeAdult,
    BRCEventTypeKid,
    BRCEventTypeParade,
    BRCEventTypeFood
};

@interface BRCEventObject : BRCDataObject <YapDatabaseRelationshipNode>

@property (nonatomic, readonly) BRCEventType eventType;

/** Camp hosting event. (To assist our full-text search indexing) */
@property (nonatomic, strong) NSString *campName;
/** Art hosting event. (To assist our full-text search indexing) */
@property (nonatomic, strong) NSString *artName;

/** PlayaEvents ID of event's camp */
@property (nonatomic, strong, readonly) NSString *hostedByCampUniqueID;
/** PlayaEvents ID of event's art */
@property (nonatomic, strong, readonly) NSString *hostedByArtUniqueID;


- (BRCArtObject*) hostedByArtWithTransaction:(YapDatabaseReadTransaction*)readTransaction;
- (BRCCampObject*) hostedByCampWithTransaction:(YapDatabaseReadTransaction*)readTransaction;


@property (nonatomic, readonly) BOOL isAllDay;

@property (nonatomic, strong, readonly) NSDate *startDate;
@property (nonatomic, strong, readonly) NSDate *endDate;

/**
 *  From PlayaEvents API, not sure what its for
 */
@property (nonatomic, readonly) BOOL checkLocation;

- (NSTimeInterval)timeIntervalUntilStart:(NSDate*)currentDate;
- (NSTimeInterval)timeIntervalUntilEnd:(NSDate*)currentDate;

/** How long the event is */
- (NSTimeInterval)timeIntervalForDuration;

/**
 *  Whether or not the event is still happening *right now*
 */
- (BOOL)isHappeningRightNow:(NSDate*)currentDate;

/**
 *  Whether or not the event ends in the next 15 minutes
 */
- (BOOL)isEndingSoon:(NSDate*)currentDate;

/**
 *  Whether or not the event starts within the next hour
 */
- (BOOL)isStartingSoon:(NSDate*)currentDate;

/** Whether or not the event has started yet */
- (BOOL)hasStarted:(NSDate*)currentDate;

/** Whether or not the event has ended */
- (BOOL)hasEnded:(NSDate*)currentDate;


/** first day of events */
+ (NSDate*) festivalStartDate;
/** first day of exodus */
+ (NSDate*) festivalEndDate;

/** Array of titles of major events, starting with first day of events @see datesOfFestival */
+ (NSArray*) majorEvents;
/** All the dates for the festival. @see majorEvents */
+ (NSArray*) datesOfFestival;

/** to be used when unsetting isFavorite */
@property (nonatomic, strong) UILocalNotification *scheduledNotification;

/** 
 *  Returns color for event status based on isOngoing
 *  isEndingSoon, and isStartingSoon.
 */
- (UIColor*) colorForEventStatus:(NSDate*)currentDate;

/**
 *  Returns Image for event status based on isOngoing
 *  isEndingSoon, and isStartingSoon.
 */
- (UIImage *)markerImageForEventStatus:(NSDate*)currentDate;

/** convert BRCEventType to display string */
+ (NSString *)stringForEventType:(BRCEventType)type;


/** eventObject must be isFavorite first */
+ (void) scheduleNotificationForEvent:(BRCEventObject*)eventObject transaction:(YapDatabaseReadWriteTransaction*)transaction;
/** eventObject must not be favorite */
+ (void) cancelScheduledNotificationForEvent:(BRCEventObject*)eventObject transaction:(YapDatabaseReadWriteTransaction*)transaction;
/** userInfo contains the event's uniqueID under this key */
+ (NSString*) localNotificationUserInfoKey;

@end
