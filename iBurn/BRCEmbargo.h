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

+ (BOOL)canShowLocationForObject:(BRCDataObject *)dataObject;

@end
NS_ASSUME_NONNULL_END
