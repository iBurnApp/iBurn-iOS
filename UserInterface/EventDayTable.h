//
//  EventDayTable.h
//  iBurn
//
//  Created by Andrew Johnson on 8/18/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "XMLTableViewController.h"
#import "NodeController.h"

@interface EventDayTable : XMLTableViewController <NodeFetchDelegate> {
  NSArray *events;  
}

@property(nonatomic,strong) NSArray *events;

- (id)initWithTitle:(NSString*)ttl;

@end
