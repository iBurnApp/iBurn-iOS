//
//  BRCDataObject+Relationships.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/18/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import "BRCDataObject.h"
@import YapDatabase;

@interface BRCDataObject (Relationships)

/** Returns all events hosted at art/camp. Not valid for event objects. */
- ( NSArray* __nonnull ) eventsWithTransaction:(YapDatabaseReadTransaction* __nonnull)readTransaction;

@end
