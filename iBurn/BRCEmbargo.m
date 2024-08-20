//
//  BRCEmbargo.m
//  iBurn
//
//  Created by David Chiles on 8/7/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCEmbargo.h"
#import "NSUserDefaults+iBurn.h"
#import "BRCSecrets.h"
#import "BRCEventObject.h"
#import "BRCCampObject.h"
#import "BRCEventObject.h"
#import <CommonCrypto/CommonDigest.h>
#import "NSData+iBurn.h"
#import "iBurn-Swift.h"

@implementation BRCEmbargo

// I wish we didn't have to put this in here
// This data should be open!
//
// To generate new passcode without salt:
// $ echo -n passcode | sha256sum
+ (BOOL)isEmbargoPasscodeString:(NSString *)passcode
{
    NSParameterAssert(passcode != nil);
    NSData *passcodeData = [passcode dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableData *hashedPasscodeData = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH];
    
    CC_SHA256(passcodeData.bytes, (int)passcodeData.length, hashedPasscodeData.mutableBytes);
    
    NSString *bundledPasscodeHash = kBRCEmbargoPasscodeSHA256Hash;
    NSString *hashString = [hashedPasscodeData brc_hexadecimalString];
    
    return [bundledPasscodeHash isEqualToString:hashString];
}

+ (BOOL)allowEmbargoedData
{
    if ([[NSUserDefaults standardUserDefaults] enteredEmbargoPasscode]) {
        return YES;
    }
    //Data is not embargoed after start of festival or if the passcode has been entered
    NSDate *now = [NSDate present];
    NSDate *festivalStartDate = [BRCEventObject festivalStartDate];
    NSTimeInterval timeLeftInterval = [now timeIntervalSinceDate:festivalStartDate];
    if (timeLeftInterval >= 0) {
        [[NSUserDefaults standardUserDefaults] setEnteredEmbargoPasscode:YES];
        return YES;
    }
    return NO;
}

+ (BOOL)canShowLocationForObject:(BRCDataObject *)dataObject
{
    if (![BRCEmbargo allowEmbargoedData]) {
#warning warning! camp data is unlocked, change me back for 2025
        // camp data is allowed
//        if ([dataObject isKindOfClass:[BRCCampObject class]] || [dataObject isKindOfClass:[BRCEventObject class]] ||
//            [dataObject isKindOfClass:[BRCArtObject class]]) {
//            return NO;
//        }
        if ([dataObject isKindOfClass:[BRCArtObject class]]) {
            return NO;
        }
    }
    return YES;
}


@end
