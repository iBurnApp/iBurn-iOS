//
//  TTTTimeIntervalFormatter+iBurn.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/1/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "TTTTimeIntervalFormatter+iBurn.h"

@implementation TTTTimeIntervalFormatter (iBurn)

+ (instancetype) brc_shortRelativeTimeFormatter {
    static TTTTimeIntervalFormatter *timeIntervalFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        timeIntervalFormatter = [[TTTTimeIntervalFormatter alloc] init];
        timeIntervalFormatter.pastDeicticExpression = nil;
        timeIntervalFormatter.presentDeicticExpression = nil;
        timeIntervalFormatter.futureDeicticExpression = nil;
        timeIntervalFormatter.usesAbbreviatedCalendarUnits = YES;
    });
    return timeIntervalFormatter;
}

@end
