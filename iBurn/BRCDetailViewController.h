//
//  BRCDetailViewController.h
//  iBurn
//
//  Created by David Chiles on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BRCDataObject, BRCObjectMetadata, BRCImageColors;

NS_ASSUME_NONNULL_BEGIN
@interface BRCDetailViewController : UITableViewController

@property (nonatomic, strong, readonly) BRCDataObject *dataObject;
@property (nonatomic, strong, readonly) BRCImageColors *colors;
/** This is the indexPath from the containing UITableView, when presented in a UIPageViewController */
@property (nonatomic, strong, nullable) NSIndexPath *indexPath;

- (instancetype)initWithDataObject:(BRCDataObject *)dataObject;

@end
NS_ASSUME_NONNULL_END
