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
		[self.tabBarItem initWithTitle:self.title image:[UIImage imageNamed:@"tweet.png"] tag:0];
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
                                               initWithTitle:@"Write"
                                               style:UIBarButtonItemStylePlain
                                               target:self
                                               action:@selector(write:)] autorelease];
	}
  return self;
}


- (void)write:(id)sender {
	TweetComposerViewController *tweetComposer = [[TweetComposerViewController alloc] initWithTitle:@"Write a Tweet"];	
	[[self navigationController] pushViewController:tweetComposer animated:YES];	
}	

@end