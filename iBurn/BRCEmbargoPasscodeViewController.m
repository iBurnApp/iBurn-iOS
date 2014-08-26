//
//  BRCEmbargoPasscodeViewController.m
//  iBurn
//
//  Created by David Chiles on 8/7/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCEmbargoPasscodeViewController.h"
#import "PureLayout.h"
#import "DAKeyboardControl.h"
#import "BRCEmbargo.h"
#import "NSUserDefaults+iBurn.h"
#import "BRCAppDelegate.h"
#import "TTTTimeIntervalFormatter+iBurn.h"
#import "BRCEventObject.h"
#import "BButton.h"
#import "BRCSocialButtonsView.h"

@interface BRCEmbargoPasscodeViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UIButton *unlockBotton;
@property (nonatomic, strong) UIButton *noPasscodeButton;
@property (nonatomic, strong) UILabel *descriptionLabel;
@property (nonatomic, strong) UITextField *passcodeTextField;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UILabel *countdownLabel;
@property (nonatomic) BOOL didAddConstraints;
@property (nonatomic, strong) NSTimer *countdownTimer;
@property (nonatomic, strong) NSLayoutConstraint *bottomCostraint;
@property (nonatomic, strong) NSLayoutConstraint *textFieldAxisConstraint;
@property (nonatomic, strong) TTTTimeIntervalFormatter *timerFormatter;
@property (nonatomic, strong) BRCSocialButtonsView *socialButtonsView;
@end

@implementation BRCEmbargoPasscodeViewController

- (void) dealloc {
    [self.countdownTimer invalidate];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    self.didAddConstraints = NO;
    
    self.containerView = [[UIView alloc] initForAutoLayout];
    
    self.noPasscodeButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.noPasscodeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.noPasscodeButton addTarget:self action:@selector(nopasscodeButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.noPasscodeButton setTitle:@"Skip" forState:UIControlStateNormal];
    self.noPasscodeButton.titleLabel.font = [UIFont systemFontOfSize:18];

    self.unlockBotton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.unlockBotton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.unlockBotton addTarget:self action:@selector(unlockButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.unlockBotton setTitle:@"Unlock" forState:UIControlStateNormal];
    self.unlockBotton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    
    self.socialButtonsView = [[BRCSocialButtonsView alloc] initWithFrame:CGRectZero];
    
    self.descriptionLabel = [[UILabel alloc] initForAutoLayout];
    self.descriptionLabel.text = @"Camp locations are restricted until the gates open due to BMan regulations. The passcode will be released to the public at 10am on Sunday 8/24.\n\nFollow @iBurnApp on Twitter or Facebook for this year's passcode, or ask a Black Rock Ranger, Playa Info or Burning Man Staffer.";
    self.descriptionLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:16];
    self.descriptionLabel.numberOfLines = 0;
    
    self.passcodeTextField = [[UITextField alloc] initForAutoLayout];
    self.passcodeTextField.secureTextEntry = YES;
    self.passcodeTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.passcodeTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.passcodeTextField.returnKeyType = UIReturnKeyDone;
    self.passcodeTextField.delegate = self;
    self.passcodeTextField.placeholder = @"Passcode";
    
    self.countdownLabel = [[UILabel alloc] initForAutoLayout];
    self.countdownLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.countdownLabel.textAlignment = NSTextAlignmentCenter;
    self.countdownLabel.numberOfLines = 0;
    self.timerFormatter = [[TTTTimeIntervalFormatter alloc] init];
    
    self.countdownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(refreshCountdownLabel:) userInfo:nil repeats:YES];
    [self.countdownTimer fire];
    
    [self.view addSubview:self.containerView];
    [self.containerView addSubview:self.descriptionLabel];
    [self.containerView addSubview:self.noPasscodeButton];
    [self.containerView addSubview:self.unlockBotton];
    [self.containerView addSubview:self.passcodeTextField];
    [self.containerView addSubview:self.countdownLabel];
    [self.containerView addSubview:self.socialButtonsView];
    
    [self setupUnlockNotification];
    
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(singleTapPressed:)];
    [self.view addGestureRecognizer:tapRecognizer];
    
    [self.view updateConstraintsIfNeeded];
    
    __weak BRCEmbargoPasscodeViewController *welf = self;
    [self.view addKeyboardNonpanningWithFrameBasedActionHandler:nil constraintBasedActionHandler:^(CGRect keyboardFrameInView, BOOL opening, BOOL closing) {
        if (opening)
        {
            welf.bottomCostraint.constant = -keyboardFrameInView.size.height;
            [UIView animateWithDuration:0.2 animations:^{
                CGFloat newAlpha = 0.0f;
                welf.descriptionLabel.alpha = newAlpha;
                welf.socialButtonsView.alpha = newAlpha;
            }];
        }
        else if (closing)
        {
            welf.bottomCostraint.constant = 0.0;
            [UIView animateWithDuration:0.5 animations:^{
                CGFloat newAlpha = 1.0f;
                welf.descriptionLabel.alpha = newAlpha;
                welf.socialButtonsView.alpha = newAlpha;
            }];
        }
    }];
}

- (void) setupUnlockNotification {
    NSDate *now = [NSDate date];
    NSDate *festivalStartDate = [BRCEventObject festivalStartDate];
    NSTimeInterval timeLeftInterval = [now timeIntervalSinceDate:festivalStartDate];
    if (timeLeftInterval >= 0) {
        [[NSUserDefaults standardUserDefaults] scheduleLocalNotificationForGateUnlock:nil];
    } else {
        UILocalNotification *existingNotification = [[NSUserDefaults standardUserDefaults] scheduledLocalNotificationForGateUnlock];
        if (existingNotification) {
            return;
        }
        UILocalNotification *unlockNotification = [[UILocalNotification alloc] init];
        unlockNotification.fireDate = festivalStartDate;
        unlockNotification.alertBody = @"Gates are open! Embargoed data can now be unlocked.";
        unlockNotification.soundName = UILocalNotificationDefaultSoundName;
        unlockNotification.alertAction = @"Unlock Now";
        unlockNotification.applicationIconBadgeNumber = 1;
        unlockNotification.userInfo = @{kBRCGateUnlockNotificationKey: @YES};
        [[NSUserDefaults standardUserDefaults] scheduleLocalNotificationForGateUnlock:unlockNotification];
    }
}

- (void) refreshCountdownLabel:(id)sender {
    NSMutableAttributedString *fullLabelString = nil;
    NSDate *now = [NSDate date];
    NSDate *festivalStartDate = [BRCEventObject festivalStartDate];
    NSTimeInterval timeLeftInterval = [now timeIntervalSinceDate:festivalStartDate];
    if (timeLeftInterval >= 0) {
        fullLabelString = [[NSMutableAttributedString alloc] initWithString:@"Gates Are Open!"];
        [self.countdownTimer invalidate];
    } else {
        // Get conversion to months, days, hours, minutes
        unsigned int unitFlags = NSHourCalendarUnit | NSMinuteCalendarUnit | NSDayCalendarUnit | NSSecondCalendarUnit;
        
        NSDateComponents *breakdownInfo = [[NSCalendar currentCalendar] components:unitFlags fromDate:now  toDate:festivalStartDate options:0];
        
        NSMutableArray *fontSizingInfo = [NSMutableArray arrayWithCapacity:5];

        fullLabelString = [[NSMutableAttributedString alloc] initWithString:@""];
        
        NSMutableArray *fontSizes = [NSMutableArray arrayWithArray:@[@(55), @(35), @(20), @(15)]];
        
        if ([breakdownInfo day]) {
            NSString *daysString = [NSString stringWithFormat:@"%d days\n", (int)[breakdownInfo day]];
            NSNumber *fontSize = [fontSizes firstObject];
            [fontSizes removeObjectAtIndex:0];
            [fontSizingInfo addObject:@[daysString, fontSize]];
        }
        if ([breakdownInfo hour]) {
            NSString *hoursString = [NSString stringWithFormat:@"%d hours\n", (int)[breakdownInfo hour]];
            NSNumber *fontSize = [fontSizes firstObject];
            [fontSizes removeObjectAtIndex:0];
            [fontSizingInfo addObject:@[hoursString, fontSize]];
        }
        if ([breakdownInfo minute]) {
            NSString *minutesString = [NSString stringWithFormat:@"%d minutes\n", (int)[breakdownInfo minute]];
            NSNumber *fontSize = [fontSizes firstObject];
            [fontSizes removeObjectAtIndex:0];
            [fontSizingInfo addObject:@[minutesString, fontSize]];
        }
        NSString *secondsString = [NSString stringWithFormat:@"%d seconds", (int)[breakdownInfo second]];
        NSNumber *fontSize = [fontSizes firstObject];
        [fontSizes removeObjectAtIndex:0];
        [fontSizingInfo addObject:@[secondsString, fontSize]];
        
        __block NSUInteger startRange = 0;
        [fontSizingInfo enumerateObjectsUsingBlock:^(NSArray *fontSizingInfo, NSUInteger idx, BOOL *stop) {
            NSNumber *size = [fontSizingInfo lastObject];
            NSString *string = [fontSizingInfo firstObject];
            [fullLabelString appendAttributedString:[[NSAttributedString alloc] initWithString:string]];
            UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Light" size:[size floatValue]];
            [fullLabelString addAttribute:NSFontAttributeName
                                    value:font
                                    range:NSMakeRange(startRange, string.length)];
            startRange += string.length;
        }];
    }

    self.countdownLabel.attributedText = fullLabelString;
}

- (void) singleTapPressed:(id)sender {
    [self.passcodeTextField resignFirstResponder];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    
    if (self.didAddConstraints) {
        return;
    }
    CGFloat statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
    [self.containerView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsMake(statusBarHeight + 5, 10, 10, 10) excludingEdge:ALEdgeBottom];
    self.bottomCostraint = [self.containerView autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self.view];
    
    [self.descriptionLabel autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsMake(0, 0, 0, 0) excludingEdge:ALEdgeBottom];
    
    [self.socialButtonsView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.descriptionLabel withOffset:10];
    [self.socialButtonsView autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:0];
    [self.socialButtonsView autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:0];
    [self.socialButtonsView autoAlignAxisToSuperviewAxis:ALAxisVertical];
    
    self.textFieldAxisConstraint = [self.passcodeTextField autoAlignAxis:ALAxisVertical toSameAxisOfView:self.containerView];
    [self.passcodeTextField autoMatchDimension:ALDimensionWidth toDimension:ALDimensionWidth ofView:self.descriptionLabel];
    [self.passcodeTextField autoSetDimension:ALDimensionHeight toSize:31.0];
    [self.passcodeTextField autoPinEdge:ALEdgeBottom toEdge:ALEdgeTop ofView:self.noPasscodeButton withOffset:-10 relation:NSLayoutRelationGreaterThanOrEqual];
    
    [self.countdownLabel autoAlignAxisToSuperviewAxis:ALAxisVertical];
    [self.countdownLabel autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:10];
    [self.countdownLabel autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:10];
    [self.countdownLabel autoPinEdge:ALEdgeBottom toEdge:ALEdgeTop ofView:self.passcodeTextField withOffset:-10];
    [self.countdownLabel autoSetDimension:ALDimensionHeight toSize:150];
    
    [self.noPasscodeButton autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.containerView withOffset:10];
    [self.noPasscodeButton autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self.containerView withOffset:-10];
    [self.noPasscodeButton autoPinEdge:ALEdgeRight toEdge:ALEdgeLeft ofView:self.unlockBotton withOffset:10 relation:NSLayoutRelationGreaterThanOrEqual];
    [self.noPasscodeButton autoSetDimension:ALDimensionHeight toSize:44.0];
    
    
    [self.unlockBotton autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.containerView withOffset:-10];
    [self.unlockBotton autoAlignAxis:ALAxisHorizontal toSameAxisOfView:self.noPasscodeButton];
    [self.unlockBotton autoMatchDimension:ALDimensionHeight toDimension:ALDimensionHeight ofView:self.noPasscodeButton];
    [self.unlockBotton autoMatchDimension:ALDimensionWidth toDimension:ALDimensionWidth ofView:self.noPasscodeButton];
    
    
    self.didAddConstraints = YES;
}

- (void)nopasscodeButtonPressed:(id)sender
{
    [self showTabBarController];
}

- (void)unlockButtonPressed:(id)sender
{
    if ([BRCEmbargo isEmbargoPasscodeString:self.passcodeTextField.text]) {
        [self setUnlocked];
    }
    else {
        [self shakeTextField:5];
    }
}

-(void)shakeTextField:(int)shakes {
    
    int direction = 1;
    if (shakes%2) {
        direction = -1;
    }
    
    if (shakes > 0) {
        self.textFieldAxisConstraint.constant = 5*direction;
    }
    else {
        self.textFieldAxisConstraint.constant = 0.0;
    }
    
    
    [UIView animateWithDuration:0.05 animations:^ {
        [self.view layoutIfNeeded];
    }
                     completion:^(BOOL finished)
     {
         if(shakes > 0)
         {
             [self shakeTextField:shakes-1];
         }
         
     }];
}

- (void)showTabBarController
{
    [self.view removeKeyboardControl];
    if (self.dismissAction) {
        self.dismissAction();
    }
}

#pragma - mark UITextfieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [self unlockButtonPressed:textField];
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}


- (void) setUnlocked {
    [[NSUserDefaults standardUserDefaults] setEnteredEmbargoPasscode:YES];
    [self showTabBarController];
}

@end
