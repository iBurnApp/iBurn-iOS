//
//  NSUserDefaults+iBurn.h
//  iBurn
//
//  Created by David Chiles on 8/1/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSUserDefaults (iBurn)

- (nullable NSArray *)selectedEventTypes;
- (void)setSelectedEventTypes:(nullable NSArray *)selectedEventTypes;

- (BOOL)showExpiredEvents;
- (void)setShowExpiredEvents:(BOOL)showEpiredEvents;

/** Whether or not to show "All Day" events */
@property (nonatomic, readwrite) BOOL showAllDayEvents;

- (BOOL)enteredEmbargoPasscode;
- (void)setEnteredEmbargoPasscode:(BOOL)enteredEmbargoPasscode;

/** Whether this device has ever taken a location fix inside the Burning Man
 *  region this season. Latched (never cleared) and year-stamped, so it re-arms
 *  next year. The un-forgeable half of the location embargo rule — see
 *  BRCEmbargoService. */
- (BOOL)enteredBurningManRegion;
- (void)setEnteredBurningManRegion:(BOOL)enteredBurningManRegion;

- (BOOL)hasViewedOnboarding;
- (void)setHasViewedOnboarding:(BOOL)hasViewedOnboarding;

@property (nonatomic, strong, readwrite, nullable) CLLocation *recentLocation;

@end

NS_ASSUME_NONNULL_END
