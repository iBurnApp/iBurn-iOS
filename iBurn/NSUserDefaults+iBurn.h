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

- (BOOL)hasViewedOnboarding;
- (void)setHasViewedOnboarding:(BOOL)hasViewedOnboarding;

@property (nonatomic, strong, readwrite, nullable) CLLocation *recentLocation;

@end

NS_ASSUME_NONNULL_END
