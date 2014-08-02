//
//  BRCEventObject.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataObject.h"

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

@interface BRCEventObject : BRCDataObject

@property (nonatomic, readonly) BRCEventType eventType;


@property (nonatomic, strong, readonly) NSString *hostedByCampUniqueID;


@property (nonatomic, readonly) BOOL isAllDay;

@property (nonatomic, strong, readonly) NSDate *startDate;
@property (nonatomic, strong, readonly) NSDate *endDate;

/**
 *  From PlayaEvents API, not sure what its for
 */
@property (nonatomic, strong, readonly) NSString *otherLocation;
/**
 *  From PlayaEvents API, not sure what its for
 */
@property (nonatomic, readonly) BOOL checkLocation;

- (NSTimeInterval)timeIntervalUntilStartDate;
- (NSTimeInterval)timeIntervalUntilEndDate;

/**
 *  Whether or not the event is still happening *right now*
 */
- (BOOL)isHappeningRightNow;

/**
 *  Whether or not the event ends in the next 15 minutes
 */
- (BOOL)isEndingSoon;

/**
 *  Whether or not the event starts within the next hour
 */
- (BOOL)isStartingSoon;

/** Whether or not the event has started yet */
- (BOOL)hasStarted;

/** Whether or not the event has ended */
- (BOOL)hasEnded;


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
- (UIColor*) colorForEventStatus;

/** convert BRCEventType to display string */
+ (NSString *)stringForEventType:(BRCEventType)type;

@end
