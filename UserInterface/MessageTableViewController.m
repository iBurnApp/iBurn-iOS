//
//  MessageTableViewController.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-12.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import "MessageTableViewController.h"
//#import "MessageComposerViewController.h"


@implementation MessageTableViewController

- (id) init {
	if (self = [super initWithSearchPlaceholder:nil]) {
		self.title = @"Messages";
    UITabBarItem *tabBarItem = [[[UITabBarItem alloc] initWithTitle:self.title image:[UIImage imageNamed:@"inbox.png"] tag:0] autorelease];
		self.tabBarItem = tabBarItem;
		//self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
    //                                           initWithTitle:@"Write"
     //                                          style:UIBarButtonItemStylePlain
      //                                         target:self
       //                                        action:@selector(write:)] autorelease];
	}
  return self;
}


- (void) write:(id)sender {
	//MessageComposerViewController *MessageComposer = [[MessageComposerViewController alloc] initWithTitle:@"Write a Message"];	
	//[[self navigationController] pushViewController:MessageComposer animated:YES];	
}	

@end