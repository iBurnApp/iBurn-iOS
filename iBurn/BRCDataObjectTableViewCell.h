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
@property (strong, nonatomic) IBOutlet UILabel *descriptionLabel;


- (void) setStyleFromDataObject:(BRCDataObject*)dataObject;

+ (NSString*) cellIdentifier;

- (void) updateDistanceLabelFromLocation:(CLLocation*)fromLocation toLocation:(CLLocation*)toLocation;

@end
