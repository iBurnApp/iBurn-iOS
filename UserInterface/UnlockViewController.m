    //
//  UnlockViewController.m
//  iBurn
//
//  Created by EFB on 8/21/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "UnlockViewController.h"
#import "CreditsViewController.h"
#import "PageViewer.h"
#import "iBurnAppDelegate.h"
#import "ContactInfoScreen.h"

@implementation UnlockViewController



- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
	if ([t checkPassword:textField.text]) {
		UIAlertView *av = [[[UIAlertView alloc]initWithTitle:@"Success" 
																								 message:@"The data is now unlocked." 
																								delegate:self 
																			 cancelButtonTitle:@"OK" 
																			 otherButtonTitles:nil]autorelease];
		[av show];
		[textField resignFirstResponder];
	} else {
		UIAlertView *av = [[[UIAlertView alloc]initWithTitle:@"Fail" 
																								 message:@"That password is incorrect." 
																								delegate:self 
																			 cancelButtonTitle:@"OK" 
																			 otherButtonTitles:nil]autorelease];
		[av show];
	}
	return NO;
}


- (id)init {
	if(self = [super init]) {
    UITabBarItem *tabBarItem = [[[UITabBarItem alloc] initWithTitle:self.title image:[UIImage imageNamed:@"lock-icon.png"] tag:0] autorelease];
		self.tabBarItem = tabBarItem;
		self.title = @"Unlock";
		[self.navigationItem setTitle:@"Unlock"];
	}
  return self;
}


- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	if (!didLoad) {
		didLoad = YES;
		return YES;
	}
  
  iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
  
  if (![t canConnectToInternet]) {
    UIAlertView *as = [[[UIAlertView alloc]initWithTitle:@"No Internet Connection" message:@"Sorry, please try again later." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil]autorelease];
    [as show];
    return NO;
  }
  
  
	PageViewer *p = [[[PageViewer alloc]initForString:[[request URL]absoluteString]]autorelease];
	[self.navigationController pushViewController:p animated:YES];
	return NO;
}


- (void) showCredits {
	CreditsViewController *c = [[[CreditsViewController alloc]init]autorelease];
	[self.navigationController pushViewController:c animated:YES];
	
}


- (void) showAbout {
	ContactInfoScreen *c = [[[ContactInfoScreen alloc]init]autorelease];
	[self.navigationController pushViewController:c animated:YES];
	
}


// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
	[super loadView];
	didLoad = NO;
	self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc]initWithTitle:@"About" 
																																						style:UIBarButtonItemStyleDone
																																					 target:self 
																																					 action:@selector(showAbout)]autorelease];	
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]initWithTitle:@"Credits" 
																																						style:UIBarButtonItemStyleDone
																																					 target:self 
																																					 action:@selector(showCredits)]autorelease];	
	CGRect fr = CGRectMake(0, 44, self.view.frame.size.width, 300);
	
	UIWebView *infoLabel = [[[UIWebView alloc]initWithFrame:fr]autorelease];
	infoLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[infoLabel loadHTMLString:@"The camp locations are embargoed until gates open.<BR><BR>The app will unlock when you get to BRC based on GPS, or if someone tells you the password.<BR><BR>We’ll announce the password at <a href=http://www.gaiagps.com/news>www.gaiagps.com/news</a><p><b>PLEASE NOTE: THE DATA IN THIS APP IS INCOMPLETE AND INACCURATE IN SOME CASES.</b></p>." baseURL:nil];
	infoLabel.delegate = self;
	[self.view addSubview:infoLabel];
	
	fr = CGRectMake(60, 15, 200, 24);
	
	UITextField *passwordField = [[[UITextField alloc]initWithFrame:fr]autorelease];
	passwordField.placeholder = @"Enter the password";
	passwordField.textAlignment = UITextAlignmentCenter;
	passwordField.borderStyle = UITextBorderStyleRoundedRect;
	passwordField.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
	passwordField.returnKeyType = UIReturnKeyDone;
  passwordField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	passwordField.delegate = self;
	iBurnAppDelegate *t = (iBurnAppDelegate *)[[UIApplication sharedApplication] delegate];
	if (![t embargoed]) {
		passwordField.text = [t getStoredPassword];
	}
	passwordField.autocorrectionType = UITextAutocorrectionTypeNo;
	[self.view addSubview:passwordField];

}

/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/

/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}


@end
