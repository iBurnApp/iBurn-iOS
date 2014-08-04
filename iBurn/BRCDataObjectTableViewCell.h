//
//  BRCDataObjectTableViewCell.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SWTableViewCell.h"

@class BRCDataObject;

@interface SWTableViewCell()
@property (nonatomic, assign) SWCellState cellState; // The state of the cell within the scroll view, can be left, right or middle
@end

@interface BRCDataObjectTableViewCell : SWTableViewCell

@property (strong, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet UILabel *subtitleLabel;

- (void) setDataObject:(BRCDataObject*)dataObject;

+ (NSString*) cellIdentifier;
+ (CGFloat) cellHeight;

@end
