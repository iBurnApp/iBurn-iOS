//
//  TweetComposerViewController.h
//  iBurn
//
//  Created by Jeffrey Johnson on 2009-01-19.
//  Copyright 2009 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface TweetComposerViewController : UIViewController <UITextViewDelegate> {
	UITextView *tweetContent;
}

- (TweetComposerViewController *)initWithTitle: (NSString *) aTitle;

@end
