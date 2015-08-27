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
    //Data is not embargoed after start of festival or if the passcode has been entered
    if ([[NSUserDefaults standardUserDefaults] enteredEmbargoPasscode]) {
        return YES;
    }
    return NO;
}

+ (BOOL)canShowLocationForObject:(BRCDataObject *)dataObject
{
    if (![BRCEmbargo allowEmbargoedData]) {
        if ([dataObject isKindOfClass:[BRCCampObject class]] || [dataObject isKindOfClass:[BRCEventObject class]] ||
            [dataObject isKindOfClass:[BRCArtObject class]]) {
            return NO;
        }
    }
    return YES;
}


@end
