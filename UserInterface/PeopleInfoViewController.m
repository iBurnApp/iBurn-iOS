//
//  PeopleInfoViewController.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-05-25.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import "PeopleInfoViewController.h"
#import "User.h"
#import "PeopleTableViewController.h"


@implementation PeopleInfoViewController

@synthesize user;


- (PeopleInfoViewController *)initWithPk:(int)userPk {
	user = [(User*)[User findByPK:userPk] retain];
	self = [super initWithTitle:user.username];
  return self;
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv {
    return 3;
}


- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    return 1;
}


- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  NSString *fullName = [NSString stringWithFormat:@"%@", self.user.name]; 
  NSArray *texts = [NSArray arrayWithObjects:self.user.username, fullName, self.user.emailAddress, nil];
  return [super tableView:tv cellForRowAtIndexPath:indexPath texts:texts];
}


- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)section {
    // Return the displayed title for the specified section.
    switch (section) {
        case 0: return @"Userame";
        case 1: return @"Name";
        case 2: return @"Contact Email";			
    }
    return nil;
}


- (NSIndexPath *)tableView:(UITableView *)tv willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Only allow selection if editing.
    return (self.editing) ? indexPath : nil;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {}


- (void)dealloc {
  [user release];
  [super dealloc];
}

@end