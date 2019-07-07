//
//  NSUserDefaults+iBurn.m
//  iBurn
//
//  Created by David Chiles on 8/1/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "NSUserDefaults+iBurn.h"

static NSString *const kBRCSelectedEventsTypesKey    = @"kBRCSelectedEventsTypesKey";
static NSString *const kBRCShowExpiredEventsKey      = @"kBRCShowExpiredEventsKey";
static NSString *const kBRCRecentLocationKey         = @"kBRCRecentLocationKey";
static NSString *const kBRCEntered2019EmbargoPasscodeKey = @"kBRCEntered2019EmbargoPasscodeKey";
static NSString *const kBRCHasViewedOnboardingKey = @"kBRCHasViewedOnboardingKey";
static NSString *const kBRCShowAllDayEventsKey = @"kBRCShowAllDayEventsKey";

NSString *const kBRCGateUnlockNotificationKey = @"kBRCGateUnlockNotificationKey";
NSString *const kBRCSortEventsByStartTimeKey = @"kBRCSortEventsByStartTimeKey";


@implementation NSUserDefaults (iBurn)
@dynamic showAllDayEvents;

- (UILocalNotification*) scheduledLocalNotificationForGateUnlock {
    NSData *localNotificationData = [self objectForKey:kBRCGateUnlockNotificationKey];
    if (localNotificationData) {
        UILocalNotification *localNotification = [NSKeyedUnarchiver unarchiveObjectWithData:localNotificationData];
        return localNotification;
    }
    return nil;
}

- (void) scheduleLocalNotificationForGateUnlock:(UILocalNotification*)localNotification {
    UILocalNotification *existingNotification = [self scheduledLocalNotificationForGateUnlock];
    if (existingNotification) {
        [[UIApplication sharedApplication] cancelLocalNotification:existingNotification];
        [self removeObjectForKey:kBRCGateUnlockNotificationKey];
    }
    if (localNotification) {
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
        NSData *localNotificationData = [NSKeyedArchiver archivedDataWithRootObject:localNotification];
        [self setObject:localNotificationData forKey:kBRCGateUnlockNotificationKey];
    } else {
        [self removeObjectForKey:kBRCGateUnlockNotificationKey];
    }
    [self synchronize];
}



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

- (void) setRecentLocation:(CLLocation *)recentLocation {
    NSData *locationData = [NSKeyedArchiver archivedDataWithRootObject:recentLocation];
    [self setObject:locationData forKey:kBRCRecentLocationKey];
    [self synchronize];
}

- (CLLocation*) recentLocation {
    NSData *locationData = [self objectForKey:kBRCRecentLocationKey];
    if (!locationData) {
        return nil;
    }
    CLLocation *location = [NSKeyedUnarchiver unarchiveObjectWithData:locationData];
    return location;
}

- (BOOL)enteredEmbargoPasscode
{
    return [self boolForKey:kBRCEntered2019EmbargoPasscodeKey];
}

- (void)setEnteredEmbargoPasscode:(BOOL)enteredEmbargoPasscode
{
    [self setBool:enteredEmbargoPasscode forKey:kBRCEntered2019EmbargoPasscodeKey];
    [self synchronize];
}

- (BOOL)hasViewedOnboarding {
    return [self boolForKey:kBRCHasViewedOnboardingKey];
}

- (void)setHasViewedOnboarding:(BOOL)hasViewedOnboarding {
    [self setBool:hasViewedOnboarding forKey:kBRCHasViewedOnboardingKey];
    [self synchronize];
}

- (void) setShowAllDayEvents:(BOOL)showAllDayEvents {
    [self setBool:showAllDayEvents forKey:kBRCShowAllDayEventsKey];
    [self synchronize];
}

- (BOOL) showAllDayEvents {
    return [self boolForKey:kBRCShowAllDayEventsKey];
}

@end
