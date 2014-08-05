//
//  NSUserDefaults+iBurn.h
//  iBurn
//
//  Created by David Chiles on 8/1/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface NSUserDefaults (iBurn)

- (NSArray *)selectedEventTypes;
- (void)setSelectedEventTypes:(NSArray *)selectedEventTypes;

- (BOOL)showExpiredEvents;
- (void)setShowExpiredEvents:(BOOL)showEpiredEvents;

@property (nonatomic, strong, readwrite) CLLocation *recentLocation;

@end
