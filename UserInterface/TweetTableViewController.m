//
//  ArtTableViewController.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-12.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import "TweetTableViewController.h"
#import "TweetComposerViewController.h"


@implementation TweetTableViewController

- (id)init {
	if (self = [super init]) {
		self.title = @"Tweets";
    UITabBarItem *tabBarItem = [[[UITabBarItem alloc] initWithTitle:self.title image:[UIImage imageNamed:@"tweet.png"] tag:0] autorelease];
		self.tabBarItem = tabBarItem;
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
                                               initWithTitle:@"Write"
                                               style:UIBarButtonItemStylePlain
                                               target:self
                                               action:@selector(write:)] autorelease];
	}
  return self;
}


- (void)write:(id)sender {
	TweetComposerViewController *tweetComposer = [[[TweetComposerViewController alloc] initWithTitle:@"Write a Tweet"] autorelease];	
	[[self navigationController] pushViewController:tweetComposer animated:YES];	
}	

@end