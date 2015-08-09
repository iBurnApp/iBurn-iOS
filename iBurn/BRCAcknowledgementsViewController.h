//
//  BRCAcknowledgementsViewController.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/10/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "VTAcknowledgementsViewController.h"
#import "TTTAttributedLabel.h"
#import "BRCSocialButtonsView.h"

@interface BRCAcknowledgementsViewController : VTAcknowledgementsViewController <TTTAttributedLabelDelegate>

@property (nonatomic, strong, readonly) TTTAttributedLabel *headerLabel;

- (instancetype) initWithHeaderLabel:(TTTAttributedLabel*)headerLabel;

@end
