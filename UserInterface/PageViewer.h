//
//  PageViewer.h
//  Trailbehind
//
//  Created by Timothy Bowen on 4/17/09.
//  Copyright 2009 TrailBehind Inc.. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ASIHTTPRequest.h"

@interface PageViewer : UIViewController <UIWebViewDelegate>{
	UIWebView *page;
	NSString *urlString;
  UIActivityIndicatorView *spinner;
  ASIHTTPRequest *request;
  UISegmentedControl *backButton, *forwardButton;
}

@property (nonatomic, retain) UIWebView *page;
@property (nonatomic, retain) NSString *urlString;

- (id)initForString:(NSString*)string;


@end
