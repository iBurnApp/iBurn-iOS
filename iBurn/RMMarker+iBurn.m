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
    UIImage *markerImage = nil;
    Class dataObjectClass = [dataObject class];
    if (dataObjectClass == [BRCArtObject class]) {
        markerImage = [UIImage imageNamed:@"BRCBluePin"];
    }
    else if (dataObjectClass == [BRCEventObject class]) {
        BRCEventObject *eventObject = (BRCEventObject*)dataObject;
        markerImage = [eventObject markerImageForEventStatus];
    }
    else if (dataObjectClass == [BRCCampObject class]) {
        markerImage = [UIImage imageNamed:@"BRCPurplePin"];
    }
    
    if (markerImage) {
        return [[RMMarker alloc] initWithUIImage:markerImage];
    }
    return nil;
}

@end
