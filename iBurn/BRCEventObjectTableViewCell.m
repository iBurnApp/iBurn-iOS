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
#import "TTTTimeIntervalFormatter+iBurn.h"

@implementation BRCEventObjectTableViewCell

- (void) setDataObject:(BRCDataObject*)dataObject {
    [super setDataObject:dataObject];
    BRCEventObject *eventObject = (BRCEventObject*)dataObject;
    if (eventObject.isAllDay) {
        self.eventTimeLabel.text = @"All Day";
    } else if (eventObject.isStartingSoon) {
        NSString *minsUntilStartString = [[TTTTimeIntervalFormatter brc_shortRelativeTimeFormatter] stringForTimeInterval:eventObject.timeIntervalUntilStartDate];
        self.eventTimeLabel.text = [NSString stringWithFormat:@"Starts %@", minsUntilStartString];
    } else if (eventObject.isHappeningRightNow) {
        NSString *minsUntilEndString = [[TTTTimeIntervalFormatter brc_shortRelativeTimeFormatter] stringForTimeInterval:eventObject.timeIntervalUntilEndDate];
        self.eventTimeLabel.text = [NSString stringWithFormat:@"Ends %@", minsUntilEndString];
    } else if (eventObject.hasEnded) {
        self.eventTimeLabel.text = @"Expired";
    } else { // Starts in long time
        self.eventTimeLabel.text = [[NSDateFormatter brc_timeOnlyDateFormatter] stringFromDate:eventObject.startDate];
    }
    UIColor *eventStatusColor = [eventObject colorForEventStatus];
    self.eventTimeLabel.textColor = eventStatusColor;
    self.eventTypeLabel.text = [BRCEventObject stringForEventType:eventObject.eventType];
}

+ (CGFloat) cellHeight {
    return 100.0f;
}

@end
