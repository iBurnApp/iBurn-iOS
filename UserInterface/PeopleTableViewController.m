//
//  PeopleTableViewController.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-12.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import "PeopleTableViewController.h"
#import "User.h"
#import "PeopleInfoViewController.h"
#import "NSObject-SQLitePersistence.h"

@implementation PeopleTableViewController

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
  [self loadUsers];
}


- (id)init {
	if(self = [super init]) {
    UITabBarItem *tabBarItem = [[[UITabBarItem alloc] initWithTitle:self.title image:[UIImage imageNamed:@"people.png"] tag:0] autorelease];
		self.tabBarItem = tabBarItem;
		self.title = @"People";
	}
  return self;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdentifier = @"Cell";
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (cell == nil) {
    cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
  }
  
	int userIndex = [indexPath indexAtPosition: [indexPath length] - 1];
	cell.textLabel.text = [[objects objectAtIndex: userIndex] objectForKey: @"userName"];	
  return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	int userIndex = [indexPath indexAtPosition: [indexPath length] - 1];
	int userPk = [[[objects objectAtIndex: userIndex] objectForKey:@"primaryKey"] intValue];
	PeopleInfoViewController *PeopleInfoView = [[[PeopleInfoViewController alloc] initWithPk:userPk] autorelease];
	[[self navigationController] pushViewController:PeopleInfoView animated:YES];
}


- (void)loadUsers {
  objects = [[NSMutableArray alloc] init];
	NSArray *arr = [User allObjects];
	for(id tc in arr) {
		NSMutableDictionary *dict = [[[NSMutableDictionary alloc] init]autorelease];
		[dict setValue:[NSNumber numberWithInt:[tc pk]] forKey:@"primaryKey"];
		[dict setObject:[tc name] forKey:@"userName"];
		[objects addObject:dict];
	}
	[self.tableView reloadData];
}


@end