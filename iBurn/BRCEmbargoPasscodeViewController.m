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
@property (nonatomic, strong) BButton *twitterButton;
@property (nonatomic, strong) BButton *facebookButton;
@property (nonatomic, strong) BButton *githubButton;

@end

@implementation BRCEmbargoPasscodeViewController

- (void) dealloc {
    [self.countdownTimer invalidate];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.didAddConstraints = NO;
    
    self.containerView = [[UIView alloc] initForAutoLayout];
    
    self.noPasscodeButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.noPasscodeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.noPasscodeButton addTarget:self action:@selector(nopasscodeButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.noPasscodeButton setTitle:@"Skip" forState:UIControlStateNormal];
    self.noPasscodeButton.titleLabel.font = [UIFont systemFontOfSize:18];
    self.noPasscodeButton.tintColor = [UIColor grayColor];

    self.unlockBotton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.unlockBotton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.unlockBotton addTarget:self action:@selector(unlockButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.unlockBotton setTitle:@"Unlock" forState:UIControlStateNormal];
    self.unlockBotton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    
    UIFont *buttonFont = [UIFont systemFontOfSize:15];
    self.facebookButton = [[BButton alloc] initWithFrame:CGRectZero type:BButtonTypeFacebook style:BButtonStyleBootstrapV3];
    self.facebookButton.titleLabel.text = @"Facebook";
    self.facebookButton.titleLabel.font = buttonFont;
    [self.facebookButton addAwesomeIcon:FAFacebook beforeTitle:YES];
    [self.facebookButton addTarget:self action:@selector(facebookButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    self.githubButton = [[BButton alloc] initWithFrame:CGRectZero type:BButtonTypeDefault style:BButtonStyleBootstrapV3];
    self.githubButton.titleLabel.text = @"GitHub";
    self.githubButton.titleLabel.font = buttonFont;
    [self.githubButton addAwesomeIcon:FAGithub beforeTitle:YES];
    [self.githubButton addTarget:self action:@selector(githubButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    self.twitterButton = [[BButton alloc] initWithFrame:CGRectZero type:BButtonTypeTwitter style:BButtonStyleBootstrapV3];
    self.twitterButton.titleLabel.text = @"Twitter";
    self.twitterButton.titleLabel.font = buttonFont;
    [self.twitterButton addAwesomeIcon:FATwitter beforeTitle:YES];
    [self.twitterButton addTarget:self action:@selector(twitterButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    
    self.descriptionLabel = [[UILabel alloc] initForAutoLayout];
    self.descriptionLabel.text = @"Camp locations are embargoed until the gates open due to BMorg restrictions. The passcode will be released to the public at 10am on Sunday 8/24.\n\nFollow @iBurnApp on Twitter or Facebook for this year's passcode, or ask a Black Rock Ranger or Burning Man Staffer.";
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
    [self.containerView addSubview:self.facebookButton];
    [self.containerView addSubview:self.twitterButton];
    [self.containerView addSubview:self.githubButton];
    
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
                welf.twitterButton.alpha = newAlpha;
                welf.facebookButton.alpha = newAlpha;
                welf.githubButton.alpha = newAlpha;
            }];
        }
        else if (closing)
        {
            welf.bottomCostraint.constant = 0.0;
            [UIView animateWithDuration:0.5 animations:^{
                CGFloat newAlpha = 1.0f;
                welf.descriptionLabel.alpha = newAlpha;
                welf.twitterButton.alpha = newAlpha;
                welf.facebookButton.alpha = newAlpha;
                welf.githubButton.alpha = newAlpha;
            }];
        }
    }];
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

- (void) twitterButtonPressed:(id)sender {
    NSURL *twitterURL = [NSURL URLWithString:@"twitter://user?screen_name=iBurnApp"];
    if ([[UIApplication sharedApplication] canOpenURL:twitterURL]) {
        [[UIApplication sharedApplication] openURL:twitterURL];
    } else {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://twitter.com/iBurnApp"]];
    }
}

- (void) facebookButtonPressed:(id)sender {
    NSURL *facebookURL = [NSURL URLWithString:@"fb://profile/322327871267883"];
    if ([[UIApplication sharedApplication] canOpenURL:facebookURL]) {
        [[UIApplication sharedApplication] openURL:facebookURL];
    } else {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://facebook.com/iBurnApp"]];
    }
}

- (void) githubButtonPressed:(id)sender {
    NSURL *githubURL = [NSURL URLWithString:@"https://github.com/Burning-Man-Earth/iBurn-iOS"];
    [[UIApplication sharedApplication] openURL:githubURL];
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
    
    [self.facebookButton autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:0];
    [self.facebookButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.descriptionLabel withOffset:10];
    [self.twitterButton autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:0];
    [self.twitterButton autoAlignAxis:ALAxisHorizontal toSameAxisOfView:self.facebookButton];
    [self.githubButton autoAlignAxis:ALAxisHorizontal toSameAxisOfView:self.facebookButton];
    [self.githubButton autoAlignAxisToSuperviewAxis:ALAxisVertical];
    [self.facebookButton autoSetDimension:ALDimensionWidth toSize:93];
    [self.facebookButton autoSetDimension:ALDimensionHeight toSize:30];
    [self.facebookButton autoMatchDimension:ALDimensionWidth toDimension:ALDimensionWidth ofView:self.githubButton];
    [self.githubButton autoMatchDimension:ALDimensionWidth toDimension:ALDimensionWidth ofView:self.twitterButton];
    [self.twitterButton autoMatchDimension:ALDimensionWidth toDimension:ALDimensionWidth ofView:self.facebookButton];
    [self.facebookButton autoMatchDimension:ALDimensionHeight toDimension:ALDimensionHeight ofView:self.githubButton];
    [self.githubButton autoMatchDimension:ALDimensionHeight toDimension:ALDimensionHeight ofView:self.twitterButton];
    [self.twitterButton autoMatchDimension:ALDimensionHeight toDimension:ALDimensionHeight ofView:self.facebookButton];
    
    
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
        [[NSUserDefaults standardUserDefaults] setEnteredEmbargoPasscode:YES];
        [self showTabBarController];
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
    [((BRCAppDelegate *)[UIApplication sharedApplication].delegate) showTabBarAnimated:YES];
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


@end
