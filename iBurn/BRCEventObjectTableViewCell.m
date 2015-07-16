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
#import "BRCDatabaseManager.h"

@implementation BRCEventObjectTableViewCell

- (void) setDataObject:(BRCDataObject*)dataObject {
    [super setDataObject:dataObject];
    BRCEventObject *eventObject = (BRCEventObject*)dataObject;
    if (eventObject.isAllDay) {
        self.rightSubtitleLabel.text = @"All Day";
    } else if (eventObject.isStartingSoon) {
        NSTimeInterval eventDuration = eventObject.timeIntervalForDuration;
        NSString *durationString = [[TTTTimeIntervalFormatter brc_shortRelativeTimeFormatter] stringForTimeInterval:eventDuration];
        NSString *minsUntilStartString = [[TTTTimeIntervalFormatter brc_shortRelativeTimeFormatter] stringForTimeInterval:eventObject.timeIntervalUntilStartDate];
        self.rightSubtitleLabel.text = [NSString stringWithFormat:@"Starts %@ (%@)", minsUntilStartString, durationString];
    } else if (eventObject.isHappeningRightNow) {
        NSString *minsUntilEndString = [[TTTTimeIntervalFormatter brc_shortRelativeTimeFormatter] stringForTimeInterval:eventObject.timeIntervalUntilEndDate];
        self.rightSubtitleLabel.text = [NSString stringWithFormat:@"Ends %@", minsUntilEndString];
    } else if (eventObject.hasEnded && eventObject.hasStarted) {
        self.rightSubtitleLabel.text = @"Expired";
    } else { // Starts in long time
        NSString *startTime = [[NSDateFormatter brc_timeOnlyDateFormatter] stringFromDate:eventObject.startDate];
        NSString *endTime = [[NSDateFormatter brc_timeOnlyDateFormatter] stringFromDate:eventObject.endDate];
        NSString *timeString = [[NSString stringWithFormat:@"%@ - %@", startTime, endTime] lowercaseString];
        self.rightSubtitleLabel.text = timeString;
    }
    UIColor *eventStatusColor = [eventObject colorForEventStatus];
    self.rightSubtitleLabel.textColor = eventStatusColor;
    NSString *eventType = [BRCEventObject stringForEventType:eventObject.eventType];
    if (!eventType.length) {
        eventType = @"None";
    }
    self.eventTypeLabel.text = eventType;
    [self setupLocationLabelFromEvent:eventObject];
}

- (void) setupLocationLabelFromEvent:(BRCEventObject*)eventObject {
    NSString *playaLocation = eventObject.playaLocation;
    NSString *locationName = nil;
    __block BRCCampObject *camp = nil;
    __block BRCArtObject *art = nil;
    // shouldn't be doing this fetch in here... best moved up to the view controller
    [[BRCDatabaseManager sharedInstance].readConnection readWithBlock:^(YapDatabaseReadTransaction * transaction) {
        camp = [eventObject hostedByCampWithTransaction:transaction];
        if (camp) {
            return;
        }
        art = [eventObject hostedByArtWithTransaction:transaction];
    }];
    if (camp) {
        locationName = camp.title;
    } else if (art) {
        locationName = art.title;
    }
    NSString *labelString = nil;
    if (locationName) {
        labelString = locationName;
    }
#ifdef DEBUG
    if (!playaLocation) {
        playaLocation = @"0:00 & ?";
    }
#endif
    if (playaLocation) {
        labelString = [labelString stringByAppendingFormat:@" - %@", playaLocation];
    }
    self.locationLabel.text = labelString;
}

@end
