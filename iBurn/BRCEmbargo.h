//
//  BRCEmbargo.h
//  iBurn
//
//  Created by David Chiles on 8/7/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BRCEmbargo : NSObject


+ (BOOL)isEmbargoPasscodeString:(NSString *)passcode;

/**Checks if the password has been entered or before gates open */
+ (BOOL)allowEmbargoedData;

@end
