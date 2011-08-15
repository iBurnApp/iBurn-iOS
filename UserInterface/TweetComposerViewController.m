//
//  TweetComposerViewController.m
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-19.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import "TweetComposerViewController.h"
#import "MultipartForm.h"


@implementation TweetComposerViewController

- (TweetComposerViewController *)initWithTitle: (NSString *) aTitle {
	self = [super init];
	self.title = aTitle;
	[self.tabBarItem initWithTitle:self.title image:NULL tag:0];
  return self;
}

- (void)loadView {
	tweetContent = [[UITextView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
	[tweetContent setDelegate:self];
	self.view = tweetContent;
	[tweetContent release];
}


- (void) textViewDidBeginEditing: (UITextView *) textViewDidBeginEditing {
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] 
											  initWithTitle:@"Send"
											  style:UIBarButtonItemStyleDone
											  target:self
											   action:@selector(sendTweet:)] 
											  autorelease];												
}


- (void) sendTweet:(id) sender {
	//Not Implemented
	UIAlertView *notImplemented = [[[UIAlertView alloc]
								   initWithTitle:@"Not Implemented"
								   message:@"This Feature Is Not Yet Implemented"
								   delegate:self 
								   cancelButtonTitle:nil
								   otherButtonTitles:@"OK", nil]autorelease];
	[notImplemented show];
	/*
	
	NSString *tweetText = [tweetContent text];	
	NSURL *postUrl = [NSURL URLWithString:@"http://pemobiletag.pictearthusa.com/geotag/image_upload/"];

	MultipartForm *form = [[MultipartForm alloc] initWithURL:postUrl];
    [form addFormField:@"tweetText" withStringData:tweetText];
	NSMutableURLRequest *postRequest = [form mpfRequest];

	NSData *urlData;
    NSURLResponse *response;
    NSError *error;
	urlData = [NSURLConnection sendSynchronousRequest:postRequest returningResponse:&response error:&error];
	 */	
	//[result release];
}


- (void)dealloc {
	[tweetContent release];
  [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

@end
