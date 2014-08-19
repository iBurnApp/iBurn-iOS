//
//  BRCEventsFilterTableViewController.h
//  iBurn
//
//  Created by David Chiles on 8/1/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BRCEventsFilterTableViewController;

@protocol BRCEventsFilterTableViewControllerDelegate <NSObject>
@required
- (void)didSetNewFilterSettingsInFilterTableViewController:(BRCEventsFilterTableViewController *)viewController;
- (void)didSetNewSortSettingsInFilterTableViewController:(BRCEventsFilterTableViewController *)viewController;
@end

@interface BRCEventsFilterTableViewController : UIViewController

@property (nonatomic, weak, readonly) id <BRCEventsFilterTableViewControllerDelegate> delegate;

- (instancetype)initWithDelegate:(id <BRCEventsFilterTableViewControllerDelegate>)delegate;

@end
