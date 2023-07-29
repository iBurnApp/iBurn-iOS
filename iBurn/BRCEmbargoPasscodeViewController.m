//
//  BRCEmbargoPasscodeViewController.m
//  iBurn
//
//  Created by David Chiles on 8/7/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCEmbargoPasscodeViewController.h"
#import "PureLayout.h"
#import "BRCEmbargo.h"
#import "NSUserDefaults+iBurn.h"
#import "BRCAppDelegate.h"
#import "BRCEventObject.h"
#import "BButton.h"
#import "BRCSocialButtonsView.h"
#import "iBurn-Swift.h"

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

    BRCImageColors *colors = Appearance.currentColors;
    self.view.backgroundColor = colors.backgroundColor;
    self.didAddConstraints = NO;
    
    self.containerView = [[UIView alloc] initForAutoLayout];
    
    self.noPasscodeButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.noPasscodeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.noPasscodeButton addTarget:self action:@selector(nopasscodeButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.noPasscodeButton setTitle:@"Skip" forState:UIControlStateNormal];
    self.noPasscodeButton.titleLabel.font = [UIFont systemFontOfSize:18];
    self.noPasscodeButton.titleLabel.textColor = colors.primaryColor;

    self.unlockBotton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.unlockBotton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.unlockBotton addTarget:self action:@selector(unlockButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.unlockBotton setTitle:@"Unlock" forState:UIControlStateNormal];
    self.unlockBotton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    self.unlockBotton.titleLabel.textColor = colors.primaryColor;
    
    self.socialButtonsView = [[BRCSocialButtonsView alloc] initWithFrame:CGRectZero];
    typeof(self) __weak weakSelf = self;
    self.socialButtonsView.buttonPressed = ^(NSURL * _Nonnull url) {
        typeof(self) strongSelf = weakSelf;
        [WebViewHelper presentWebViewWithUrl:url from:strongSelf];
    };
    
    self.descriptionLabel = [[UILabel alloc] initForAutoLayout];
    self.descriptionLabel.text = @"Location data is restricted until gates open due to an embargo imposed by the Burning Man organization. The app will automatically unlock itself after gates open at 12:01am Sunday and you're on playa. \n\nWe will post the passcode publicly after gates open. Please do not ask us for the passcode, thanks!";
    self.descriptionLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:16];
    self.descriptionLabel.numberOfLines = 0;
    self.descriptionLabel.textColor = colors.primaryColor;
    
    self.passcodeTextField = [[UITextField alloc] initForAutoLayout];
    self.passcodeTextField.secureTextEntry = YES;
    self.passcodeTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.passcodeTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.passcodeTextField.returnKeyType = UIReturnKeyDone;
    self.passcodeTextField.delegate = self;
    self.passcodeTextField.textColor = colors.primaryColor;
    self.passcodeTextField.backgroundColor = colors.backgroundColor;
    self.passcodeTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                    initWithString:@"Passcode"
                                                    attributes:@{
        NSForegroundColorAttributeName: colors.secondaryColor
    }];
    self.countdownLabel = [[UILabel alloc] initForAutoLayout];
    self.countdownLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.countdownLabel.textAlignment = NSTextAlignmentCenter;
    self.countdownLabel.numberOfLines = 0;
    self.countdownLabel.textColor = colors.primaryColor;

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
        
    UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(singleTapPressed:)];
    [self.view addGestureRecognizer:tapRecognizer];
    
    [self.view updateConstraintsIfNeeded];
}

- (BOOL) isDataUnlocked {
    NSDate *now = [NSDate present];
    NSDate *festivalStartDate = [BRCEventObject festivalStartDate];
    NSTimeInterval timeLeftInterval = [now timeIntervalSinceDate:festivalStartDate];
    return timeLeftInterval >= 0 ||
    [[NSUserDefaults standardUserDefaults] enteredEmbargoPasscode];
}

- (void) refreshCountdownLabel:(id)sender {
    NSMutableAttributedString *fullLabelString = nil;
    NSDate *now = [NSDate present];
    NSDate *festivalStartDate = [BRCEventObject festivalStartDate];
    if ([self isDataUnlocked]) {
        fullLabelString = [[NSMutableAttributedString alloc] initWithString:@"Location Data Unlocked!"];
        [self.countdownTimer invalidate];
        self.passcodeTextField.hidden = YES;
        self.unlockBotton.hidden = YES;
        self.noPasscodeButton.hidden = YES;
    } else {
        // Get conversion to months, days, hours, minutes
        unsigned int unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitDay | NSCalendarUnitSecond;
        
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

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if ([self isDataUnlocked]) {
        [self setUnlocked];
    }
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    
    if (self.didAddConstraints) {
        return;
    }
    [self.containerView autoPinEdgeToSuperviewSafeArea:ALEdgeTop withInset:8];
    self.bottomCostraint = [self.containerView autoPinEdgeToSuperviewSafeArea:ALEdgeBottom];
    [self.containerView autoPinEdgeToSuperviewMargin:ALEdgeLeft];
    [self.containerView autoPinEdgeToSuperviewMargin:ALEdgeRight];
        
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

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.2 animations:^{
        self.bottomCostraint.constant = -(self.view.frame.size.height / 2);
        CGFloat newAlpha = 0.0f;
        self.descriptionLabel.alpha = newAlpha;
        self.socialButtonsView.alpha = newAlpha;
        [self.view layoutIfNeeded];
    }];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self.view layoutIfNeeded];
    [UIView animateWithDuration:0.5 animations:^{
        self.bottomCostraint.constant = 0.0;
        CGFloat newAlpha = 1.0f;
        self.descriptionLabel.alpha = newAlpha;
        self.socialButtonsView.alpha = newAlpha;
        [self.view layoutIfNeeded];
    }];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (void) setUnlocked {
    [[NSUserDefaults standardUserDefaults] setEnteredEmbargoPasscode:YES];
    [self showTabBarController];
}

@end
