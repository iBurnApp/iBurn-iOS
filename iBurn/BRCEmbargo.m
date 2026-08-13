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

// Every verdict below comes from BRCEmbargoService (EmbargoService.swift), which
// applies the shared strict rule:
//
//     passcodeUnlocked || (inRegion && now >= unlockDate(tier))
//
// A date alone never unlocks anything: the device clock is user-settable, so the
// old "after festival start" check (which also latched the passcode flag) was
// defeated by moving Settings ▸ Date & Time forward. This class stays as the
// Objective-C façade the app already calls; only the answers changed.
+ (BOOL)allowEmbargoedData
{
    return [BRCEmbargoService allowEmbargoedData];
}

+ (BOOL)canShowCampLocations
{
    return [BRCEmbargoService canShowCampLocations];
}

+ (BOOL)canShowArtLocations
{
    return [BRCEmbargoService canShowArtLocations];
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
