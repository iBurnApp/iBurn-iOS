//
//  BRCSocialButtonsView.h
//  iBurn
//
//  Created by Christopher Ballinger on 8/10/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

@import UIKit;
@class BButton;

NS_ASSUME_NONNULL_BEGIN

@interface BRCSocialButtonsView : UIView

@property (nonatomic, strong) BButton *twitterButton;
@property (nonatomic, strong) BButton *facebookButton;
@property (nonatomic, strong) BButton *githubButton;
@property (nonatomic, copy, nullable) void (^buttonPressed)(NSURL *url);

@end

NS_ASSUME_NONNULL_END
