//
//  BRCOnboardingViewController.h
//  iBurn
//
//  Created by Chris Ballinger on 7/26/16.
//  Copyright © 2016 Burning Man Earth. All rights reserved.
//

#import <UIKit/UIKit.h>
@import Onboard;

@interface BRCOnboardingViewController : OnboardingViewController

/** Returns newly configured onboarding view */
+ (instancetype)onboardingViewControllerWithCompletion:(dispatch_block_t)completionBlock;

@end
