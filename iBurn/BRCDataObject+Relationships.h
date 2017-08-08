//
//  BRCDataObject+Relationships.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/18/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import "BRCDataObject.h"
@import YapDatabase;

@class BRCEventObject;

NS_ASSUME_NONNULL_BEGIN
@interface BRCDataObject (Relationships)

/** Returns all events hosted at art/camp. Not valid for event objects. */
- ( NSArray<BRCEventObject*> *) eventsWithTransaction:(YapDatabaseReadTransaction*)transaction;

@end
NS_ASSUME_NONNULL_END
