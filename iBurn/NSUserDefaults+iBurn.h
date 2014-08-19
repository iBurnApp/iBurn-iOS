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

- (BOOL)shouldSortEventsByStartTime;
- (void)setShouldSortEventsByStartTime:(BOOL)shouldSortByStart;

- (BOOL)showExpiredEvents;
- (void)setShowExpiredEvents:(BOOL)showEpiredEvents;

- (BOOL)enteredEmbargoPasscode;
- (void)setEnteredEmbargoPasscode:(BOOL)enteredEmbargoPasscode;

@property (nonatomic, strong, readwrite) CLLocation *recentLocation;

@end
