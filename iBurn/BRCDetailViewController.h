//
//  BRCDetailViewController.h
//  iBurn
//
//  Created by David Chiles on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>

@class  BRCDataObject;

@interface BRCDetailViewController : UITableViewController

- (instancetype)initWithDataObject:(BRCDataObject *)dataObject;

@end
