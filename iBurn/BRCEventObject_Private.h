//
//  BRCEventObject_Private.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCEventObject.h"

// used by data import for NSUserDefaults
// fetch values using static accessor methods
extern NSString * const kBRCStartDate2017Key;
extern NSString * const kBRCEndDate2017Key;
extern NSString * const kBRCMajorEvents2017Key;

@interface BRCEventObject()
@property (nonatomic, strong, readwrite) NSDate *startDate;
@property (nonatomic, strong, readwrite) NSDate *endDate;
@end
