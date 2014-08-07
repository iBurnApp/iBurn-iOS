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

@interface BRCEmbargoPasscodeViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UIButton *unlockBotton;
@property (nonatomic, strong) UIButton *noPasscodeButton;
@property (nonatomic, strong) UITextView *descriptionTextView;
@property (nonatomic, strong) UITextField *passcodeTextField;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic) BOOL didAddConstraints;

@property (nonatomic, strong) NSLayoutConstraint *bottomCostraint;
@property (nonatomic, strong) NSLayoutConstraint *textFieldAxisConstraint;

@end

@implementation BRCEmbargoPasscodeViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.didAddConstraints = NO;
    
    self.containerView = [[UIView alloc] initForAutoLayout];
    
    self.noPasscodeButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.noPasscodeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.noPasscodeButton addTarget:self action:@selector(nopasscodeButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.noPasscodeButton setTitle:@"No Passcode" forState:UIControlStateNormal];
    
    self.unlockBotton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    self.unlockBotton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.unlockBotton addTarget:self action:@selector(unlockButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    [self.unlockBotton setTitle:@"Unlock" forState:UIControlStateNormal];
    
    self.descriptionTextView = [[UITextView alloc] initForAutoLayout];
    self.descriptionTextView.text = @"Describe what embargo is and what is diabled until Burning Man starts";
    self.descriptionTextView.editable = NO;
    
    self.passcodeTextField = [[UITextField alloc] initForAutoLayout];
    self.passcodeTextField.secureTextEntry = YES;
    self.passcodeTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.passcodeTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.passcodeTextField.returnKeyType = UIReturnKeyDone;
    self.passcodeTextField.delegate = self;
    
    [self.view addSubview:self.containerView];
    [self.containerView addSubview:self.descriptionTextView];
    [self.containerView addSubview:self.noPasscodeButton];
    [self.containerView addSubview:self.unlockBotton];
    [self.containerView addSubview:self.passcodeTextField];
    
    
    [self.view updateConstraintsIfNeeded];
    
    __weak BRCEmbargoPasscodeViewController *welf = self;
    [self.view addKeyboardNonpanningWithFrameBasedActionHandler:nil constraintBasedActionHandler:^(CGRect keyboardFrameInView, BOOL opening, BOOL closing) {
        if (opening)
        {
            welf.bottomCostraint.constant = -keyboardFrameInView.size.height;
        }
        else if (closing)
        {
            welf.bottomCostraint.constant = 0.0;
        }
    }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.passcodeTextField becomeFirstResponder];
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    
    if (!self.didAddConstraints) {
        [self.containerView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsMake(30, 0, 0, 0) excludingEdge:ALEdgeBottom];
        self.bottomCostraint = [self.containerView autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self.view];
        
        [self.descriptionTextView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsMake(10, 10, 10, 10) excludingEdge:ALEdgeBottom];
        [self.descriptionTextView autoPinEdge:ALEdgeBottom toEdge:ALEdgeTop ofView:self.passcodeTextField withOffset:0 relation:NSLayoutRelationGreaterThanOrEqual];
        
        self.textFieldAxisConstraint = [self.passcodeTextField autoAlignAxis:ALAxisVertical toSameAxisOfView:self.containerView];
        [self.passcodeTextField autoMatchDimension:ALDimensionWidth toDimension:ALDimensionWidth ofView:self.descriptionTextView];
        [self.passcodeTextField autoSetDimension:ALDimensionHeight toSize:31.0];
        [self.passcodeTextField autoPinEdge:ALEdgeBottom toEdge:ALEdgeTop ofView:self.noPasscodeButton withOffset:-10 relation:NSLayoutRelationGreaterThanOrEqual];
        
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

@end
