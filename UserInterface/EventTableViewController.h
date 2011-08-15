//
//  EventTableViewController.h
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-08-22.
//  Copyright 2009 Burning Man Earth. All rights reserved.

#import "XMLTableViewController.h"
#import <UIKit/UIKit.h>

@class EventDayTable;
@interface EventTableViewController : XMLTableViewController {

  EventDayTable *eventDayTable;
  NSArray *dayArray;
}

@property (nonatomic,retain) EventDayTable *eventDayTable;

@end
