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
#import "BRCArtObject.h"
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

+ (BOOL)canShowCampLocations
{
    if ([BRCEmbargo allowEmbargoedData]) {
        return YES;
    }
    NSDate *now = [NSDate present];
    return [now timeIntervalSinceDate:YearSettings.campLocationUnlock] >= 0;
}

+ (BOOL)canShowArtLocations
{
    return [BRCEmbargo allowEmbargoedData];
}

+ (BOOL)canShowLocationForObject:(BRCDataObject *)dataObject
{
    if ([dataObject isKindOfClass:[BRCArtObject class]]) {
        return [BRCEmbargo canShowArtLocations];
    }
    if ([dataObject isKindOfClass:[BRCEventObject class]]) {
        // An event at an art installation would leak the art location, so it
        // stays on the art tier; everything else unlocks with camps.
        BRCEventObject *event = (BRCEventObject *)dataObject;
        if (event.hostedByArtUniqueID.length > 0) {
            return [BRCEmbargo canShowArtLocations];
        }
        return [BRCEmbargo canShowCampLocations];
    }
    if ([dataObject isKindOfClass:[BRCCampObject class]]) {
        return [BRCEmbargo canShowCampLocations];
    }
    return YES;
}


@end
