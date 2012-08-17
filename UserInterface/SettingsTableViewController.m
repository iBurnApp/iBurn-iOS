//
//  SettingsTableViewController.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-25.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import "SettingsTableViewController.h"


@implementation SettingsTableViewController

- (id)init {
	if( self = [super init]) {
    UITabBarItem *tabBarItem = [[[UITabBarItem alloc] initWithTitle:self.title image:[UIImage imageNamed:@"settings2.png"] tag:0] autorelease];
		self.tabBarItem = tabBarItem;
		self.title=@"Settings";
	}
    return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

@end