//
//  NewsViewController.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-11.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import "NewsViewController.h"


@implementation NewsViewController

- (id)init {
	if( self = [super init]) {
    UITabBarItem *tabBarItem = [[[UITabBarItem alloc] initWithTitle:self.title image:[UIImage imageNamed:@"news.png"] tag:0] autorelease];
		self.tabBarItem = tabBarItem;
		self.title = @"News";
	}
	return self;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

@end
