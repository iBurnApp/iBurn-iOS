//
//  NSUserDefaults+iBurn.h
//  iBurn
//
//  Created by David Chiles on 8/1/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

extern NSString *const kBRCGateUnlockNotificationKey;

@interface NSUserDefaults (iBurn)

/** Existing notification */
- (UILocalNotification*) scheduledLocalNotificationForGateUnlock;
/** This will automatically schedule the notification too. */
- (void) scheduleLocalNotificationForGateUnlock:(UILocalNotification*)localNotification;

- (NSArray *)selectedEventTypes;
- (void)setSelectedEventTypes:(NSArray *)selectedEventTypes;

- (BOOL)showExpiredEvents;
- (void)setShowExpiredEvents:(BOOL)showEpiredEvents;

/** Whether or not search on event view shows results for all days */
@property (nonatomic, readwrite) BOOL searchSelectedDayOnly;

/** Whether or not to show "All Day" events */
@property (nonatomic, readwrite) BOOL showAllDayEvents;

- (BOOL)enteredEmbargoPasscode;
- (void)setEnteredEmbargoPasscode:(BOOL)enteredEmbargoPasscode;

- (BOOL)hasViewedOnboarding;
- (void)setHasViewedOnboarding:(BOOL)hasViewedOnboarding;

@property (nonatomic, strong, readwrite) CLLocation *recentLocation;

@end
