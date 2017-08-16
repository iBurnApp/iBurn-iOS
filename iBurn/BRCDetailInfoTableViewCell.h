//
//  BRCDetailInfoTableViewCell.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/1/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BRCDetailCellInfo, BRCImageColors, BRCDataObject;

NS_ASSUME_NONNULL_BEGIN
@interface BRCDetailInfoTableViewCell : UITableViewCell

@property (nonatomic, strong) UIImageView *artImageView;

- (void) setDetailCellInfo:(BRCDetailCellInfo*)cellInfo object:(BRCDataObject*)object colors:(BRCImageColors*)colors;

@property (nonatomic, class, readonly) NSString* cellIdentifier;

@end
NS_ASSUME_NONNULL_END
