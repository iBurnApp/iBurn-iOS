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
#import "BRCDatabaseManager.h"
#import "BRCEmbargo.h"
#import "BRCCampObject.h"
#import <QuartzCore/QuartzCore.h>
#import "iBurn-Swift.h"

@implementation BRCEventObjectTableViewCell

- (void) setDataObject:(BRCDataObject*)dataObject metadata:(BRCObjectMetadata *)metadata {
    [super setDataObject:dataObject metadata:metadata];
    BRCEventObject *eventObject = (BRCEventObject*)dataObject;
    NSDate *now = [NSDate present];
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
        NSString *durationString = [DateFormatters  stringForTimeInterval:eventDuration];
        NSTimeInterval startDuration = [eventObject timeIntervalUntilStart:now];
        NSString *minsUntilStartString = [DateFormatters  stringForTimeInterval:startDuration];
        if (!minsUntilStartString.length && startDuration == 0) {
            minsUntilStartString = @"now!";
        }
        self.rightSubtitleLabel.text = [NSString stringWithFormat:@"Starts %@ (%@)", minsUntilStartString, durationString];
    } else if ([eventObject isHappeningRightNow:now]) {
        NSTimeInterval endDuration = [eventObject timeIntervalUntilEnd:[NSDate present]];
        NSString *minsUntilEndString = [DateFormatters  stringForTimeInterval:endDuration];
        if (!minsUntilEndString.length && endDuration == 0) {
            minsUntilEndString = @"0 min";
        }
        NSString *startTime = [[NSDateFormatter brc_timeOnlyDateFormatter] stringFromDate:eventObject.startDate];
        self.rightSubtitleLabel.text = [NSString stringWithFormat:@"%@ (%@ left)", startTime, minsUntilEndString];
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
    NSString *durationString = [DateFormatters  stringForTimeInterval:eventDuration];
    NSString *dayOfWeekLetter = [[NSDateFormatter brc_dayOfWeekDateFormatter] stringFromDate:eventObject.startDate];
    NSString *firstLetter = [dayOfWeekLetter substringToIndex:3];
    NSString *timeString = [[NSString stringWithFormat:@"%@ (%@)", startTime, durationString] lowercaseString];
    NSString *text = [NSString stringWithFormat:@"%@ %@", firstLetter, timeString];
    return text;
}

- (void) setupLocationLabelFromEvent:(BRCEventObject*)eventObject {
    //NSString *playaLocation = eventObject.playaLocation;
    NSString *hostName = nil;
    __block BRCCampObject *camp = nil;
    __block BRCArtObject *art = nil;
    __block BRCDataObject *host = nil;
    // shouldn't be doing this fetch in here... best moved up to the view controller
    [BRCDatabaseManager.shared.uiConnection readWithBlock:^(YapDatabaseReadTransaction * transaction) {
        camp = [eventObject hostedByCampWithTransaction:transaction];
        if (camp) {
            return;
        }
        art = [eventObject hostedByArtWithTransaction:transaction];
    }];
    if (camp) {
        host = camp;
        hostName = camp.title;
    } else if (art) {
        host = art;
        hostName = art.title;
    } else {
        host = eventObject;
        hostName = eventObject.otherLocation;
    }
    self.hostLabel.text = hostName;
    
    [self setupLocationLabel:self.locationLabel dataObject:host];
    [self setupCampThumbnailFromCamp:camp];
}

- (void)setupCampThumbnailFromCamp:(BRCCampObject *)camp {
    if (!self.campThumbnailView) {
        return;
    }
    
    if (camp && camp.localThumbnailURL) {
        UIImage *image = [UIImage imageWithContentsOfFile:camp.localThumbnailURL.path];
        if (image) {
            self.campThumbnailView.image = image;
            self.campThumbnailView.hidden = NO;
            self.campThumbnailView.contentMode = UIViewContentModeScaleAspectFill;
            
            // Apply image colors for theming
            [self applyCampImageColorsFromCamp:camp withImage:image];
        } else {
            self.campThumbnailView.hidden = YES;
        }
    } else {
        self.campThumbnailView.hidden = YES;
    }
}

- (void)applyCampImageColorsFromCamp:(BRCCampObject *)camp withImage:(UIImage *)image {
    // Only use cached colors, don't extract new ones
    __block BRCImageColors *imageColors = nil;
    [BRCDatabaseManager.shared.uiConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
        BRCObjectMetadata *metadata = [camp metadataWithTransaction:transaction];
        if ([metadata conformsToProtocol:@protocol(BRCThumbnailImageColorsProtocol)]) {
            id<BRCThumbnailImageColorsProtocol> metadataWithColors = (id<BRCThumbnailImageColorsProtocol>)metadata;
            imageColors = metadataWithColors.thumbnailImageColors;
        }
    }];
    
    if (imageColors) {
        // Use cached colors
        [self setupLabelColorsWithImageColors:imageColors];
    }
    // If no cached colors, just don't apply any theming
}

- (void)setupLabelColorsWithImageColors:(BRCImageColors *)imageColors {
    if (!imageColors) return;
    
    // Apply theme colors to labels with animation
    [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
        // Main content labels
        self.titleLabel.textColor = imageColors.primaryColor;
        self.hostLabel.textColor = imageColors.secondaryColor;
        
        // Event details labels - use detail color for better readability
        self.eventTypeLabel.textColor = imageColors.detailColor;
        self.locationLabel.textColor = imageColors.detailColor;
        self.descriptionLabel.textColor = imageColors.detailColor;
        
        // Time and distance labels
        self.rightSubtitleLabel.textColor = imageColors.secondaryColor;
        self.subtitleLabel.textColor = imageColors.detailColor; // Walk/bike distance
        
        // Background
        self.backgroundColor = imageColors.backgroundColor;
    } completion:nil];
}

@end
