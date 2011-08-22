//
//  CreditsViewController.h
//  iBurn
//
//  Created by Andrew Johnson on 8/21/11.

#import <MessageUI/MessageUI.h>

@interface CreditsViewController : UITableViewController <UIWebViewDelegate, MFMailComposeViewControllerDelegate> {
  BOOL didLoad;
}

@end
