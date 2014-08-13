//
//  BRCDataObjectTableViewCell.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MCSwipeTableViewCell.h"
#import <CoreLocation/CoreLocation.h>

@class BRCDataObject;

@interface BRCDataObjectTableViewCell : MCSwipeTableViewCell

@property (strong, nonatomic) IBOutlet UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet UILabel *subtitleLabel;

- (void) setStyleFromDataObject:(BRCDataObject*)dataObject;

+ (NSString*) cellIdentifier;
+ (CGFloat) cellHeight;

- (void) setTitleLabelBold:(BOOL)isBold;
- (void) updateDistanceLabelFromLocation:(CLLocation*)fromLocation toLocation:(CLLocation*)toLocation;

@end
