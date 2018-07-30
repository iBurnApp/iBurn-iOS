//
//  BRCEventsFilterTableViewController.h
//  iBurn
//
//  Created by David Chiles on 8/1/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BRCEventsFilterTableViewController;

NS_ASSUME_NONNULL_BEGIN
@protocol BRCEventsFilterTableViewControllerDelegate <NSObject>
@required
- (void)didSetNewFilterSettings:(BRCEventsFilterTableViewController *)viewController;
- (void)didSetNewSortSettings:(BRCEventsFilterTableViewController *)viewController;
@end

@interface BRCEventsFilterTableViewController : UIViewController

@property (nonatomic, weak, readonly) id <BRCEventsFilterTableViewControllerDelegate> delegate;

- (instancetype)initWithDelegate:(nullable id <BRCEventsFilterTableViewControllerDelegate>)delegate;

@end
NS_ASSUME_NONNULL_END
