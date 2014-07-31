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
- (BOOL)isOngoing;


@end
