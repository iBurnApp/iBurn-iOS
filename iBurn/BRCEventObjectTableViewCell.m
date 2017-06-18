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
#import "BRCEmbargo.h"

@implementation BRCEventObjectTableViewCell

- (void) setDataObject:(BRCDataObject*)dataObject {
    [super setDataObject:dataObject];
    BRCEventObject *eventObject = (BRCEventObject*)dataObject;
    NSDate *now = [NSDate date];
    if (eventObject.isAllDay) {
        NSString *dayOfWeekLetter = [[NSDateFormatter brc_dayOfWeekDateFormatter] stringFromDate:eventObject.startDate];
        NSString *timeString = nil;
        if (dayOfWeekLetter.length >= 3) {
            NSString *firstLetter = [dayOfWeekLetter substringToIndex:3];
            timeString = [NSString stringWithFormat:@"%@ (All Day)", firstLetter];
        }
        self.rightSubtitleLabel.text = timeString;
    } else if ([eventObject isStartingSoon:now]) {
        NSTimeInterval eventDuration = eventObject.timeIntervalForDuration;
        NSString *durationString = [[TTTTimeIntervalFormatter brc_shortRelativeTimeFormatter] stringForTimeInterval:eventDuration];
        NSTimeInterval startDuration = [eventObject timeIntervalUntilStart:now];
        NSString *minsUntilStartString = [[TTTTimeIntervalFormatter brc_shortRelativeTimeFormatter] stringForTimeInterval:startDuration];
        if (!minsUntilStartString.length && startDuration == 0) {
            minsUntilStartString = @"now!";
        }
        self.rightSubtitleLabel.text = [NSString stringWithFormat:@"Starts %@ (%@)", minsUntilStartString, durationString];
    } else if ([eventObject isHappeningRightNow:now]) {
        NSTimeInterval endDuration = [eventObject timeIntervalUntilEnd:[NSDate date]];
        NSString *minsUntilEndString = [[TTTTimeIntervalFormatter brc_shortRelativeTimeFormatter] stringForTimeInterval:endDuration];
        self.rightSubtitleLabel.text = [NSString stringWithFormat:@"Ends %@", minsUntilEndString];
    } else if ([eventObject hasEnded:now] && [eventObject hasStarted:now]) {
        NSString *text = [self defaultEventText:eventObject];
        self.rightSubtitleLabel.text = text;
    } else { // Starts in long time
        NSString *text = [self defaultEventText:eventObject];
        self.rightSubtitleLabel.text = text;
    }
    UIColor *eventStatusColor = [eventObject colorForEventStatus:now];
    self.rightSubtitleLabel.textColor = eventStatusColor;
    NSString *eventType = [BRCEventObject stringForEventType:eventObject.eventType];
    if (!eventType.length) {
        eventType = @"None";
    }
    self.eventTypeLabel.text = eventType;
    [self setupLocationLabelFromEvent:eventObject];
}

- (NSString*) defaultEventText:(BRCEventObject*)eventObject {
    NSString *startTime = [[NSDateFormatter brc_timeOnlyDateFormatter] stringFromDate:eventObject.startDate];
    NSTimeInterval eventDuration = eventObject.timeIntervalForDuration;
    NSString *durationString = [[TTTTimeIntervalFormatter brc_shortRelativeTimeFormatter] stringForTimeInterval:eventDuration];
    NSString *dayOfWeekLetter = [[NSDateFormatter brc_dayOfWeekDateFormatter] stringFromDate:eventObject.startDate];
    NSString *firstLetter = [dayOfWeekLetter substringToIndex:3];
    NSString *timeString = [[NSString stringWithFormat:@"%@ (%@)", startTime, durationString] lowercaseString];
    NSString *text = [NSString stringWithFormat:@"%@ %@", firstLetter, timeString];
    return text;
}

- (void) setupLocationLabelFromEvent:(BRCEventObject*)eventObject {
    NSString *playaLocation = eventObject.playaLocation;
    NSString *locationName = nil;
    __block BRCCampObject *camp = nil;
    __block BRCArtObject *art = nil;
    // shouldn't be doing this fetch in here... best moved up to the view controller
    [BRCDatabaseManager.shared.readConnection readWithBlock:^(YapDatabaseReadTransaction * transaction) {
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
    if (!playaLocation && camp.playaLocation) {
        playaLocation = camp.playaLocation;
    }
    if (!playaLocation && art.playaLocation) {
        playaLocation = art.playaLocation;
    }
    if (!playaLocation) {
        playaLocation = @"0:00 & ?";
    }
    if (![BRCEmbargo canShowLocationForObject:eventObject]) {
        playaLocation = @"Location Restricted";
    }
    if (playaLocation) {
        labelString = [labelString stringByAppendingFormat:@" - %@", playaLocation];
    }
    self.locationLabel.text = labelString;
}

@end
