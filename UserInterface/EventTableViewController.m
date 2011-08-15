//
//  EventTableViewController.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-08-22.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import "EventTableViewController.h"
#import "Event.h"
#import "EventInfoViewController.h"
#import "EventDayTable.h"
#import "iBurnAppDelegate.h"

@implementation EventTableViewController
@synthesize eventDayTable;

- (void) requestDone {
  if (eventDayTable) [eventDayTable requestDone];
}


- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  [[t eventNodeController]loadDBEvents];
}


- (id)init {
	if (self = [super initWithSearchPlaceholder:@""]) {
		[self.tabBarItem initWithTitle:self.title image:[UIImage imageNamed:@"events.png"] tag:0];
		self.title = @"Events";
		[self.navigationItem setTitle:@"Events"];
    dayArray = [[NSArray arrayWithObjects:
                @"August 30", 
                @"August 31", 
                @"September 1", 
                @"September 2", 
                @"September 3", 
                @"September 4", 
                @"September 5", 
                @"September 6", 
                @"September 7",nil]retain]; 
	}
  return self;
}
- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return [dayArray count];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	int eventIndex = [indexPath indexAtPosition: [indexPath length] - 1];
	eventDayTable = [[[EventDayTable alloc] initWithTitle:[dayArray objectAtIndex:eventIndex]]autorelease];
	[[self navigationController] pushViewController:eventDayTable animated:YES];
}

   
- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *MyIdentifier = @"MyIdentifier";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:MyIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:MyIdentifier] autorelease];
  }
	int storyIndex = [indexPath indexAtPosition: [indexPath length] - 1];
	cell.textLabel.text = [dayArray objectAtIndex: storyIndex];
	return cell;	
}



@end