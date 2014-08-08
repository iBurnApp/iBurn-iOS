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


@implementation BRCEmbargo

+ (BOOL)isEmbargoPasscodeString:(NSString *)passcode
{
    return [passcode isEqualToString:kBRCEmbargoPasscode];
}

+ (BOOL)allowEmbargoedData
{
    //Data is not embargoed after start of festival or if the passcode has been entered
    if ([[NSUserDefaults standardUserDefaults] enteredEmbargoPasscode] || [[BRCEventObject festivalStartDate] timeIntervalSinceNow] < 0) {
        return YES;
    }
    return NO;
}

+ (BOOL)canShowLocaitonForObject:(BRCDataObject *)dataObject
{
    if (![BRCEmbargo allowEmbargoedData]) {
        if ([dataObject isKindOfClass:[BRCCampObject class]] || [dataObject isKindOfClass:[BRCEventObject class]]) {
            return NO;
        }
    }
    return YES;
}


@end
