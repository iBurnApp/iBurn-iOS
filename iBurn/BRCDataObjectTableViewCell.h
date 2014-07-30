//
//  BRCDataObjectTableViewCell.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BRCDataObject;

@interface BRCDataObjectTableViewCell : UITableViewCell

@property (strong, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet UILabel *subtitleLabel;

- (void) setDataObject:(BRCDataObject*)dataObject;

+ (NSString*) cellIdentifier;
+ (CGFloat) cellHeight;

@end
