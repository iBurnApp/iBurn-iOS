//
//  BRCDetailInfoTableViewCell.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/1/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BRCDetailCellInfo;

@interface BRCDetailInfoTableViewCell : UITableViewCell

- (void) setDetailCellInfo:(BRCDetailCellInfo*)cellInfo;

+ (NSString*)cellIdentifier;

@end
