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

- (void) setStyleFromDataObject:(BRCDataObject*)dataObject {
    [super setStyleFromDataObject:dataObject];
    BRCEventObject *eventObject = (BRCEventObject*)dataObject;
    if (eventObject.isAllDay) {
        self.eventTimeLabel.text = @"All Day";
    } else if (eventObject.isStartingSoon) {
        NSString *minsUntilStartString = [[TTTTimeIntervalFormatter brc_shortRelativeTimeFormatter] stringForTimeInterval:eventObject.timeIntervalUntilStartDate];
        self.eventTimeLabel.text = [NSString stringWithFormat:@"Starts %@", minsUntilStartString];
    } else if (eventObject.isHappeningRightNow) {
        NSString *minsUntilEndString = [[TTTTimeIntervalFormatter brc_shortRelativeTimeFormatter] stringForTimeInterval:eventObject.timeIntervalUntilEndDate];
        self.eventTimeLabel.text = [NSString stringWithFormat:@"Ends %@", minsUntilEndString];
    } else if (eventObject.hasEnded && eventObject.hasStarted) {
        self.eventTimeLabel.text = @"Expired";
    } else { // Starts in long time
        self.eventTimeLabel.text = [[NSDateFormatter brc_timeOnlyDateFormatter] stringFromDate:eventObject.startDate];
    }
    UIColor *eventStatusColor = [eventObject colorForEventStatus];
    self.eventTimeLabel.textColor = eventStatusColor;
    NSString *eventType = [BRCEventObject stringForEventType:eventObject.eventType];
    if (!eventType.length) {
        eventType = @"None";
    }
    self.eventTypeLabel.text = eventType;
    [self setEventDayLabelFromDate:eventObject.startDate];
}

+ (CGFloat) cellHeight {
    return 140.0f;
}

- (void) setEventDayLabelFromDate:(NSDate*)eventStartDate {
    if (!eventStartDate) {
        self.eventDayLabel.text = @"None";
        return;
    }
    NSString *dayOfWeekString = [[NSDateFormatter brc_dayOfWeekDateFormatter] stringFromDate:eventStartDate];
    NSString *shortDateString = [[NSDateFormatter brc_shortDateFormatter] stringFromDate:eventStartDate];
    self.eventDayLabel.text = [NSString stringWithFormat:@"%@ %@", dayOfWeekString, shortDateString];
}

@end
