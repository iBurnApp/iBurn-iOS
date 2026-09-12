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
// applies the shared per-tier rule:
//
//     camp: passcodeUnlocked || now >= campLocationUnlock
//     art:  passcodeUnlocked || (inRegion && now >= eventStart)
//
// For the art tier a date alone never unlocks anything: the device clock is
// user-settable, so the old "after festival start" check (which also latched the
// passcode flag) was defeated by moving Settings ▸ Date & Time forward. The camp
// tier was relaxed to a date-only unlock on 2026-08-22 so the week-early camp
// address release is usable while planning from home. This class stays as the
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

@end
