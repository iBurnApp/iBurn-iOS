//
//  NSUserDefaults+iBurn.m
//  iBurn
//
//  Created by David Chiles on 8/1/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "NSUserDefaults+iBurn.h"

static NSString *const kBRCSelectedEventsTypesKey = @"kBRCSelectedEventsTypesKey";
static NSString *const kBRCShowExpiredEventsKey   = @"kBRCShowExpiredEventsKey";

@implementation NSUserDefaults (iBurn)

- (NSArray *)selectedEventTypes
{
    return [self objectForKey:kBRCSelectedEventsTypesKey];
}
- (void)setSelectedEventTypes:(NSArray *)selectedEventTypes
{
    if ([selectedEventTypes count]) {
        [self setObject:selectedEventTypes forKey:kBRCSelectedEventsTypesKey];
    }
    else {
        [self removeObjectForKey:kBRCSelectedEventsTypesKey];
    }
    [self synchronize];
}

- (BOOL)showExpiredEvents
{
    return [self boolForKey:kBRCShowExpiredEventsKey];
}
- (void)setShowExpiredEvents:(BOOL)showEpiredEvents
{
    [self setBool:showEpiredEvents forKey:kBRCShowExpiredEventsKey];
    [self synchronize];
}

@end
