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
static NSString *const kBRCEntered2024EmbargoPasscodeKey = @"kBRCEntered2024EmbargoPasscodeKey";
static NSString *const kBRCHasViewedOnboardingKey = @"kBRCHasViewedOnboardingKey";
static NSString *const kBRCShowAllDayEventsKey = @"kBRCShowAllDayEventsKey";

NSString *const kBRCSortEventsByStartTimeKey = @"kBRCSortEventsByStartTimeKey";


@implementation NSUserDefaults (iBurn)
@dynamic showAllDayEvents;

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
    NSError *error = nil;
    NSData *locationData = [NSKeyedArchiver archivedDataWithRootObject:recentLocation requiringSecureCoding:YES error:&error];
    if (error) {
        NSLog(@"Error serializing location: %@", error);
    }
    [self setObject:locationData forKey:kBRCRecentLocationKey];
    [self synchronize];
}

- (CLLocation*) recentLocation {
    NSData *locationData = [self objectForKey:kBRCRecentLocationKey];
    if (!locationData) {
        return nil;
    }
    NSError *error = nil;
    CLLocation *location = [NSKeyedUnarchiver unarchivedObjectOfClass:CLLocation.class fromData:locationData error:&error];
    if (error) {
        NSLog(@"Error deserializing location: %@", error);
    }
    return location;
}

- (BOOL)enteredEmbargoPasscode
{
    return [self boolForKey:kBRCEntered2024EmbargoPasscodeKey];
}

- (void)setEnteredEmbargoPasscode:(BOOL)enteredEmbargoPasscode
{
    [self setBool:enteredEmbargoPasscode forKey:kBRCEntered2024EmbargoPasscodeKey];
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
