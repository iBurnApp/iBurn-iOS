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
#import "FavoritesTableViewController.h"
#import "EventNodeController.h"

@implementation EventTableViewController
@synthesize eventDayTable;

- (void) requestDone {
  if (eventDayTable) [eventDayTable requestDone];
}


- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  EventNodeController *eventNode = (EventNodeController*)[t eventNodeController];
  [eventNode loadDBEvents];
}


- (id)init {
	if (self = [super initWithSearchPlaceholder:@""]) {
    UITabBarItem *tabBarItem = [[[UITabBarItem alloc] initWithTitle:self.title image:[UIImage imageNamed:@"events.png"] tag:0] autorelease];
		self.tabBarItem = tabBarItem;
		self.title = @"Events";
		[self.navigationItem setTitle:@"Events"];
    dayArray = [[NSArray arrayWithObjects:
								 kDay1String,
								 kDay2String, 
                kDay3String, 
                kDay4String, 
                kDay5String, 
                kDay6String, 
                kDay7String, 
                kDay8String,nil]retain];
    
	}
  return self;
}


- (void) showFavorites {
	FavoritesTableViewController *f = [[[FavoritesTableViewController alloc]init]autorelease];
	[self.navigationController pushViewController:f animated:YES];
}

- (void) loadView {
  [super loadView];
	/*self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]initWithTitle:@"Favorites" 
																																						style:UIBarButtonItemStyleDone 
																																					 target:self action:@selector(showFavorites)]autorelease];
	
	*/
	 [sortControl release];
	sortControl = nil;
  self.tableView.tableHeaderView = nil;

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
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:MyIdentifier] autorelease];
  }
	int storyIndex = [indexPath indexAtPosition: [indexPath length] - 1];
  NSString *labelText = [dayArray objectAtIndex: storyIndex];
	cell.textLabel.text = labelText;
  cell.detailTextLabel.text = [EventDayTable subtitleString:labelText];
	return cell;	
}



@end