//
//  RMMarker+iBurn.m
//  iBurn
//
//  Created by David Chiles on 7/31/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "RMMarker+iBurn.h"
#import "BRCDataObject.h"
#import "BRCArtObject.h"
#import "BRCCampObject.h"
#import "BRCEventObject.h"

@implementation RMMarker (iBurn)

+ (instancetype)brc_defaultMarkerForDataObject:(BRCDataObject *)dataObject
{
    UIColor *tintColor = nil;
    Class dataObjectClass = [dataObject class];
    if (dataObjectClass == [BRCArtObject class]) {
        tintColor = [UIColor blueColor];
    }
    else if (dataObjectClass == [BRCEventObject class]) {
        BRCEventObject *eventObject = (BRCEventObject*)dataObject;
        tintColor = [eventObject colorForEventStatus];
    }
    else if (dataObjectClass == [BRCCampObject class]) {
        tintColor = [UIColor purpleColor];
    }
    
    if (tintColor) {
        return [[RMMarker alloc] initWithMapboxMarkerImage:nil tintColor:tintColor];
    }
    return nil;
}

@end
