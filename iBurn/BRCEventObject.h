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

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kBRCEventCampEdgeName;
extern NSString * const kBRCEventArtEdgeName;

@interface BRCEventObject : BRCDataObject <YapDatabaseRelationshipNode>

@property (nonatomic, readonly) BRCEventType eventType;

/** Camp hosting event. (To assist our full-text search indexing) */
@property (nonatomic, strong, nullable) NSString *campName;
/** Art hosting event. (To assist our full-text search indexing) */
@property (nonatomic, strong, nullable) NSString *artName;

/** PlayaEvents ID of event's camp */
@property (nonatomic, strong, nullable) NSString *hostedByCampUniqueID;
/** PlayaEvents ID of event's art */
@property (nonatomic, strong, nullable) NSString *hostedByArtUniqueID;


- (nullable BRCArtObject*) hostedByArtWithTransaction:(YapDatabaseReadTransaction*)readTransaction;
- (nullable BRCCampObject*) hostedByCampWithTransaction:(YapDatabaseReadTransaction*)readTransaction;
/** Returns either camp or art */
- (nullable BRCDataObject*) hostWithTransaction:(YapDatabaseReadTransaction*)readTransaction;

@property (nonatomic, readonly) BOOL isAllDay;

@property (nonatomic, strong, readonly) NSDate *startDate;
@property (nonatomic, strong, readonly) NSDate *endDate;

/**
 *  From PlayaEvents API, not sure what its for
 */
@property (nonatomic, readonly) BOOL checkLocation;

/**
 *  Free form text entry for events hosted in weird places
 */
@property (nonatomic, strong, readonly, nullable) NSString *otherLocation;

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
 *  Whether or not the event starts within the next 30 min
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
/** All the dates for the festival. @see majorEvents */
+ (NSArray<NSDate*>*) datesOfFestival;

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

/** Updates calendar entry. Note: this will also re-save the object. */
- (void) refreshCalendarEntry:(YapDatabaseReadWriteTransaction*)transaction;

- (BRCEventMetadata*) eventMetadataWithTransaction:(YapDatabaseReadTransaction*)transaction;

@end

NS_ASSUME_NONNULL_END

