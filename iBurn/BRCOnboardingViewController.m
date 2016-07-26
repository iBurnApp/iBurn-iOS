//
//  BRCOnboardingViewController.m
//  iBurn
//
//  Created by Chris Ballinger on 7/26/16.
//  Copyright © 2016 Burning Man Earth. All rights reserved.
//

#import "BRCOnboardingViewController.h"
#import "iBurn-Swift.h"
@import AVFoundation;

@interface BRCOnboardingViewController ()
@property (nonatomic, strong) id observer;
@end

@implementation BRCOnboardingViewController

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.observer) {
        [[NSNotificationCenter defaultCenter] removeObserver:self.observer];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // fill frame w/ video
    self.moviePlayerController.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    // loop video http://stackoverflow.com/a/26401680
    __weak typeof(self) weakVC = self; // prevent memory cycle
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    self.observer = [noteCenter addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                                          object:nil // any object can send
                                           queue:nil // the queue of the sending
                                      usingBlock:^(NSNotification *note) {
                                          // holding a pointer to avPlayer to reuse it
                                          [weakVC.moviePlayerController.player seekToTime:kCMTimeZero];
                                          [weakVC.moviePlayerController.player play];
                                      }];
}

/** Returns newly configured onboarding view */
+ (BRCOnboardingViewController *)onboardingViewControllerWithCompletion:(dispatch_block_t)completionBlock {
    OnboardingContentViewController *firstPage = [OnboardingContentViewController contentWithTitle:@"Welcome to iBurn" body:@"\nLet's get started!" image:nil buttonText:@"📍 Enable Location" action:^{
        [BRCPermissions promptForLocation:^{
            NSLog(@"BRCPermissions promptForLocation");
        }];
    }];
    firstPage.movesToNextViewController = YES;
    
    OnboardingContentViewController *secondPage = [OnboardingContentViewController contentWithTitle:@"Reminders" body:@"When you favorite events we can remind you about them later." image:nil buttonText:@"⏰ Enable Notifications" action:^{
        [BRCPermissions promptForPush:^{
            NSLog(@"BRCPermissions promptForPush");
        }];
    }];
    secondPage.movesToNextViewController = YES;
    
    OnboardingContentViewController *thirdPage = [OnboardingContentViewController contentWithTitle:@"Search" body:@"Find whatever your heart desires.\n\n\n...especially bacon and coffee." image:nil buttonText:nil action:nil];
    
    OnboardingContentViewController *fourthPage = [OnboardingContentViewController contentWithTitle:@"Nearby" body:@"Quickly find cool new things going on around you.\n\n\n...or just find the closest toilet." image:nil buttonText:nil action:nil];
    
    OnboardingContentViewController *lastPage = [OnboardingContentViewController contentWithTitle:@"Thank you!" body:@"If you enjoy using iBurn, please spread the word." image:nil buttonText:@"🔥 Ok let's burn!" action:completionBlock];
    
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *moviePath = [bundle pathForResource:@"onboarding_loop_final" ofType:@"mp4"];
    NSURL *movieURL = [NSURL fileURLWithPath:moviePath];
    
    BRCOnboardingViewController *onboardingVC = [[BRCOnboardingViewController alloc] initWithBackgroundVideoURL:movieURL contents:@[firstPage, secondPage, thirdPage, fourthPage, lastPage]];
    onboardingVC.shouldFadeTransitions = YES;
    onboardingVC.fadePageControlOnLastPage = YES;
    onboardingVC.stopMoviePlayerWhenDisappear = YES;
    
    // If you want to allow skipping the onboarding process, enable skipping and set a block to be executed
    // when the user hits the skip button.
    // onboardingVC.allowSkipping = YES;
    onboardingVC.skipHandler = completionBlock;
    
    return onboardingVC;
}

@end
