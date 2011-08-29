//
//  EventDayTable.h
//  iBurn
//
//  Created by Andrew Johnson on 8/18/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "XMLTableViewController.h"


@interface EventDayTable : XMLTableViewController {

  NSArray *events;
	int eventIndex;
  
}


@property(nonatomic,retain) NSArray *events;

@end
