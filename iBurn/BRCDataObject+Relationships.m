//
//  BRCDataObject+Relationships.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/18/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import "BRCDataObject+Relationships.h"
#import "BRCArtObject.h"
#import "BRCCampObject.h"
#import "BRCEventObject.h"
#import "BRCDatabaseManager.h"

@implementation BRCDataObject (Relationships)

/** Returns all events hosted at art/camp. Not valid for event objects. */
- ( NSArray* __nonnull ) eventsWithTransaction:(YapDatabaseReadTransaction* __nonnull)readTransaction {
    NSParameterAssert(readTransaction != nil);
    if (!readTransaction) {
        return @[];
    }
    if (![[self class] isSubclassOfClass:[BRCArtObject class]] &&
        ![[self class] isSubclassOfClass:[BRCCampObject class]]) {
        NSAssert(YES, @"Only camp or art is valid here");
        return @[];
    }
    NSMutableArray *events = [NSMutableArray array];
    
    NSString *yapCollection = [[self class] yapCollection];
    
    NSString *sourceKey = self.uniqueID;
    NSString *extName = BRCDatabaseManager.shared.relationships;
    YapDatabaseRelationshipTransaction *relationshipTransaction = [readTransaction ext:extName];
    [relationshipTransaction enumerateEdgesWithName:nil
                                          sourceKey:nil
                                         collection:nil
                                     destinationKey:sourceKey
                                         collection:yapCollection
                                         usingBlock:^(YapDatabaseRelationshipEdge *edge, BOOL *stop) {
        BRCEventObject *event = [readTransaction objectForKey:edge.sourceKey inCollection:edge.sourceCollection];
        if (event && [event isKindOfClass:[BRCEventObject class]]) {
            [events addObject:event];
        }
    }];
    return events;
}

@end
