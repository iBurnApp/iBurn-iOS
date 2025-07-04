//
//  BRCEventObjectTableViewCell.h
//  iBurn
//
//  Created by Christopher Ballinger on 7/29/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCDataObjectTableViewCell.h"

NS_ASSUME_NONNULL_BEGIN
@interface BRCEventObjectTableViewCell : BRCDataObjectTableViewCell

@property (weak, nonatomic) IBOutlet UILabel *hostLabel;
@property (strong, nonatomic) IBOutlet UILabel *eventTypeLabel;
@property (strong, nonatomic) IBOutlet UILabel *locationLabel;
@property (weak, nonatomic) IBOutlet UIImageView *campThumbnailView;

@end
NS_ASSUME_NONNULL_END
