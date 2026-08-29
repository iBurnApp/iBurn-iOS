//
//  BRCEmbargo.h
//  iBurn
//
//  Created by David Chiles on 8/7/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@class BRCDataObject;

NS_ASSUME_NONNULL_BEGIN
@interface BRCEmbargo : NSObject


+ (BOOL)isEmbargoPasscodeString:(NSString *)passcode;

/**Checks if the password has been entered or before gates open */
+ (BOOL)allowEmbargoedData;

/** Camp tier: the API ToS allows theme camp locations to be shown starting
 12:01 am on the Sunday of the week before the event (YearSettings.campLocationUnlock).
 Date-only — no GPS fix required, so the week-early release is usable off playa. */
+ (BOOL)canShowCampLocations;

/** Art tier: art locations stay restricted until gates open AND the device has been
 inside the Burning Man region (or the passcode was entered). */
+ (BOOL)canShowArtLocations;

+ (BOOL)canShowLocationForObject:(BRCDataObject *)dataObject;

@end
NS_ASSUME_NONNULL_END
