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
@property (nonatomic, strong, readonly) BRCSocialButtonsView *socialButtonsView;

- (instancetype) initWithHeaderLabel:(TTTAttributedLabel*)headerLabel;

@end
