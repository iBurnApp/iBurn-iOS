//
//  YapDatabaseViewConnection+iBurn.m
//  iBurn
//
//  Created by Chris Ballinger on 2/24/17.
//  Copyright © 2017 Chris Ballinger. All rights reserved.
//

#import "YapDatabaseViewConnection+iBurn.h"
#import "iBurn-Swift.h"

@implementation YapDatabaseViewConnection (iBurn)

- (BRCSectionRowChanges*) brc_getSectionRowChangesForNotifications:(NSArray<NSNotification*> *)notifications
                                                      withMappings:(YapDatabaseViewMappings *)mappings {
    NSParameterAssert(notifications != nil);
    NSParameterAssert(mappings != nil);
    NSArray<YapDatabaseViewSectionChange*> *sc = nil;
    NSArray<YapDatabaseViewRowChange*> *rc = nil;
    [self getSectionChanges:&sc rowChanges:&rc forNotifications:notifications withMappings:mappings];
    if (!sc) {
        sc = @[];
    }
    if (!rc) {
        rc = @[];
    }
    BRCSectionRowChanges *src = [[BRCSectionRowChanges alloc] initWithSectionChanges:sc rowChanges:rc];
    return src;
}

@end
