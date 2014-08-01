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
    
    UIFont *font = self.titleLabel.font;
    UIFont *newFont = nil;
    if (eventObject.isFavorite) {
        newFont = [UIFont fontWithDescriptor:[[font fontDescriptor] fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold] size:font.pointSize];
    } else {
        newFont = [UIFont fontWithDescriptor:[[font fontDescriptor] fontDescriptorWithSymbolicTraits:0] size:font.pointSize];
    }
    self.titleLabel.font = newFont;
}

@end
