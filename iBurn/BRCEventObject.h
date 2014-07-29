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
    BRCEventTypeParade,
    BRCEventTypeFood
};

@interface BRCEventObject : BRCDataObject

@property (nonatomic, readonly) BRCEventType eventType;


@property (nonatomic, strong, readonly) NSString *hostedByCampUniqueID;

/**
 *  NSArray of BRCEventTime objects
 */
@property (nonatomic, strong, readonly) NSArray *times;


@property (nonatomic, readonly) BOOL allDay;


/**
 *  From PlayaEvents API, not sure what its for
 */
@property (nonatomic, strong, readonly) NSString *otherLocation;
/**
 *  From PlayaEvents API, not sure what its for
 */
@property (nonatomic, readonly) BOOL checkLocation;


@end
