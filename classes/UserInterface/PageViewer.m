//
//  PageViewer.m
//  Trailbehind
//
//  Created by Timothy Bowen on 4/17/09.
//  Copyright 2009 TrailBehind Inc.. All rights reserved.
//

#import "PageViewer.h"
#import "SimpleDiskCache.h"
@implementation PageViewer

@synthesize page, urlString;

// load a web page from cache or from the net
- (void) displayWebpage:(NSString*) html withURL:(NSURL*)url {
  [page loadHTMLString:html baseURL:url];
}


- (void) loadURL:(NSURL*)url withCache:(BOOL) useCache {
  if (useCache) {
    NSData* cached = [SimpleDiskCache getDataForURL:url];
    if (cached) {
      [self displayWebpage:[[NSString alloc] initWithData:cached encoding:NSUTF8StringEncoding]
                   withURL:url];
      return;
    }
  }
  
  request = [ASIHTTPRequest requestWithURL:url];  
  request.delegate = self;
  request.didFinishSelector = @selector(webpageRequestFinished:);
  request.didFailSelector = @selector(webpageRequestFailed:);
  
  [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
  [request startAsynchronous];
  
}


// The designated initializer. Override to perform setup that is required before the view is loaded.
- (id)initForString:(NSString*)string {
  self = [super init];
	urlString = string;
	return self;
}


- (void) updateNavMenu {
  //NSLog(urlString);
  //NSLog(page.request.URL.absoluteString);
  if ([page.request.URL.absoluteString isEqualToString:urlString]) {
    [backButton setEnabled:NO];
  } else {
    [backButton setEnabled:YES];
  }
  if (page.canGoForward) {
    [forwardButton setEnabled:YES];
  } else {
    [forwardButton setEnabled:NO];
  }
}  

- (void) goBack:(id)sender { 
  if ([page canGoBack]) [page goBack];
  else [self loadURL:[NSURL URLWithString:urlString] withCache:YES];
  [self updateNavMenu];
}  
- (void) goForward:(id)sender { 
  [page goForward];
  [self updateNavMenu];
}  

- (void) setStyle:(UISegmentedControl*)seg {
  seg.momentary = YES;
  seg.segmentedControlStyle = UISegmentedControlStyleBar;
}    
  
- (void) loadView {
  [super loadView];
  CGRect fr = CGRectMake(0,0,self.view.frame.size.width,self.view.frame.size.height);
  self.page = [[UIWebView alloc] initWithFrame:fr];
	self.page.delegate = self;
	self.page.scalesPageToFit = YES;  
	[self.view addSubview: self.page];		
  [self loadURL:[NSURL URLWithString:urlString] withCache:YES];
  int spinnerSize = 35;
  CGRect spinnerFrame = CGRectMake((self.page.frame.size.width-spinnerSize)/2,(self.page.frame.size.height-spinnerSize-70)/2,spinnerSize,spinnerSize);
  spinner = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
  spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin; 
  spinner.frame = spinnerFrame;
  [spinner startAnimating];
  [self.page addSubview:spinner];
  self.page.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;	

  NSArray *items = [NSArray arrayWithObjects:@"Back", nil];
  backButton = [[UISegmentedControl alloc] initWithItems:items];
  backButton.frame = CGRectMake(5, 0, backButton.frame.size.width, 30);
  backButton.tintColor = [UIColor lightGrayColor];
  [backButton addTarget:self action:@selector(goBack:) forControlEvents:UIControlEventValueChanged];
  [self setStyle: backButton];  
  items = [NSArray arrayWithObjects:@"Next", nil];
  forwardButton = [[UISegmentedControl alloc] initWithItems:items];
  forwardButton.frame = CGRectMake(15+backButton.frame.size.width, 0, forwardButton.frame.size.width, 30);
  forwardButton.tintColor = [UIColor lightGrayColor];
  [forwardButton addTarget:self action:@selector(goForward:) forControlEvents:UIControlEventValueChanged];
  [self setStyle: forwardButton];  

  UIView *v = [[UIView alloc]initWithFrame:CGRectMake(0,7,backButton.frame.size.width + forwardButton.frame.size.width + 15,30)];
  [v addSubview:backButton];
  [v addSubview:forwardButton];
  UIBarButtonItem *segmentBarItem = [[UIBarButtonItem alloc] initWithCustomView:v];
	self.navigationItem.rightBarButtonItem = segmentBarItem;
}


// display the page and cache it 
- (void)webpageRequestFinished:(ASIHTTPRequest *)req {
  NSString* response = [req responseString];
  [SimpleDiskCache cacheURL:[req url] forData:[request responseData]];
  [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
  if (page) [self displayWebpage:response withURL:[req url]];
}


// failure callback
- (void)webpageRequestFailed:(ASIHTTPRequest *)req {
	//NSError *error = [req error];	
  [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
  //NSLog(@"%@", error);
  //self.navigationItem.title = ERROR_WORD;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; 
	// Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}




//UIWebView Delegate Methods Feature
- (void)webViewDidFinishLoad:(UIWebView *)webView {
  [spinner removeFromSuperview];
  [self updateNavMenu];
}


- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
  
  [spinner removeFromSuperview];

	if ([error code] != -999) {
	  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Sorry, there was a problem loading the page." delegate:self cancelButtonTitle:@"Hide"otherButtonTitles:nil];
	  [alert show];
	}
}



- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {  
  return YES;
}  

- (void) viewWillDisappear:(BOOL)animated {
  page.delegate = nil;
  request.delegate = nil;
  [super viewWillDisappear:animated];
}

@end
