//
//  PFAnalytics+iBurn.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/12/15.
//  Copyright (c) 2015 Burning Man Earth. All rights reserved.
//

#import "PFAnalytics+iBurn.h"

@implementation PFAnalytics (iBurn)

+ (void) brc_trackEventInBackground:(NSString*)name object:(BRCDataObject*)object {
    NSParameterAssert(object != nil);
    NSParameterAssert(name != nil);
    if (!name || !object) {
        return;
    }
    object = [object copy];
    NSMutableDictionary *dimensions = [NSMutableDictionary dictionary];
    if (object.title) {
        [dimensions setObject:object.title forKey:@"title"];
    }
    NSString *objectClass = NSStringFromClass(object.class);
    if (objectClass) {
        [dimensions setObject:objectClass forKey:@"type"];
    }
    if (object.uniqueID) {
        [dimensions setObject:object.uniqueID forKey:@"playaEventsId"];
    }
    if (object.isFavorite) {
        [dimensions setObject:@"true" forKey:@"isFavorite"];
    }
    [PFAnalytics trackEventInBackground:name dimensions:dimensions block:nil];
}

@end
