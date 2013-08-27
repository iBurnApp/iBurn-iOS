//
//  BRCEventObjectTableViewCell.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCEventObjectTableViewCell.h"
#import "BRCEventObject.h"
#import "NSDateFormatter+iBurn.h"

@implementation BRCEventObjectTableViewCell

- (void) setDataObject:(BRCDataObject*)dataObject {
    [super setDataObject:dataObject];
    BRCEventObject *eventObject = (BRCEventObject*)dataObject;
    if (eventObject.isAllDay) {
        self.eventTimeLabel.text = @"All Day";
    } else {
        self.eventTimeLabel.text = [[NSDateFormatter brc_timeOnlyDateFormatter] stringFromDate:eventObject.startDate];
    }
    self.eventTimeLabel.textAlignment = NSTextAlignmentRight;
    
    UIColor *eventStatusColor = [eventObject colorForEventStatus];
    self.eventTimeLabel.textColor = eventStatusColor;
}

@end
