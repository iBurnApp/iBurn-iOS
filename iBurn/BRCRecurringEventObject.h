//
//  BRCRecurringEventObject.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCEventObject.h"

/**
 *  The reason this exists is because PlayaEvents API gives us an 'occurence_set' for each event.
 *  However it is much easier for us to split these reoccurring events into separate objects.
 */

@interface BRCRecurringEventObject : BRCEventObject
/**
 *  NSArray of BRCEventTime objects
 */
@property (nonatomic, strong, readonly) NSArray *eventTimes;

/**
 *  Regular BRCEventObjects duplicated based on the eventTimes.  
 *  This is only used in the BRCDataImporter class and shouldn't be used directly.
 *
 *  @return duplicated BRCEventObject
 */
- (NSArray*) eventObjects;

@end
