//
//  EventTableViewController.h
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-08-22.
//  Copyright 2009 Burning Man Earth. All rights reserved.

#import "XMLTableViewController.h"
#import "NodeController.h"
#import <UIKit/UIKit.h>
#import "EventDayTable.h"



@interface EventTableViewController : XMLTableViewController <NodeFetchDelegate> {

  EventDayTable *eventDayTable;
  NSArray *dayArray;
}

@property (nonatomic, strong) EventDayTable *eventDayTable;



@end
