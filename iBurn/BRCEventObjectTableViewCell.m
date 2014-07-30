//
//  BRCEventObjectTableViewCell.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCEventObjectTableViewCell.h"
#import "BRCEventObject.h"

@implementation BRCEventObjectTableViewCell

- (void) setDataObject:(BRCDataObject*)dataObject {
    [super setDataObject:dataObject];
    BRCEventObject *eventObject = (BRCEventObject*)dataObject;
    self.eventTimeLabel.text = eventObject.startDate.description;
}

@end
