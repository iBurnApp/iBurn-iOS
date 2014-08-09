//
//  BRCStringPickerViewController.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/6/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCStringPickerView.h"
#import "PureLayout.h"
#import "UIColor+iBurn.h"

@interface BRCStringPickerView ()
@property (nonatomic, strong, readwrite) UIPickerView *pickerView;
@property (nonatomic, strong, readwrite) UIToolbar *toolbar;
@property (nonatomic, readwrite) BOOL hasAddedConstraints;
@property (nonatomic, strong, readwrite) NSArray *pickerStrings;
@property (nonatomic, strong) NSMutableArray *constraintsAddedToSuperview;
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, weak, readwrite) UIViewController *presentingViewController;
@property (nonatomic, readwrite) BOOL isVisible;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIView *backgroundView;
@end

@implementation BRCStringPickerView

- (instancetype)initWithTitle:(NSString *)title pickerStrings:(NSArray *)pickerStrings initialSelection:(NSUInteger)initialSelection doneBlock:(BRCStringPickerDoneBlock)doneBlock cancelBlock:(BRCStringPickerCancelBlock)cancelBlock {
    if (self = [super init]) {
        self.pickerStrings = [pickerStrings copy];
        
        self.doneBlock = doneBlock;
        self.cancelBlock = cancelBlock;
        
        self.containerView = [[UIView alloc] initForAutoLayout];
        [self addSubview:self.containerView];
        
        self.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.5];
        // Do any additional setup after loading the view.
        self.constraintsAddedToSuperview = [NSMutableArray array];
        
        [self setupToolbarWithTitle:title];
        [self setupPickerViewWithInitialSelection:initialSelection];
        self.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return self;
}

- (void) setupPickerViewWithInitialSelection:(NSUInteger)initialSelection {
    self.pickerView = [[UIPickerView alloc] initForAutoLayout];
    self.pickerView.dataSource = self;
    self.pickerView.backgroundColor = [UIColor whiteColor];
    [self.pickerView selectRow:initialSelection inComponent:0 animated:NO];
    self.pickerView.delegate = self;
    [self.containerView addSubview:self.pickerView];
}

- (void) setupToolbarWithTitle:(NSString*)title {
    self.toolbar = [[UIToolbar alloc] initForAutoLayout];
    self.toolbar.backgroundColor = [UIColor brc_navBarColor];
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneButtonPressed:)];
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonPressed:)];
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 185, 30)];
    self.titleLabel.text = title;
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    UIBarButtonItem *titleItem = [[UIBarButtonItem alloc] initWithCustomView:self.titleLabel];
    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    [self.toolbar setItems:@[cancelButton, flexibleSpace, titleItem, flexibleSpace, doneButton]];
    [self.containerView addSubview:self.toolbar];
}

- (void)updateConstraints {
    [super updateConstraints];
    if (self.hasAddedConstraints) {
        return;
    }
    [self.toolbar autoAlignAxisToSuperviewAxis:ALAxisVertical];
    [self.toolbar autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero excludingEdge:ALEdgeBottom];
    [self.pickerView autoAlignAxisToSuperviewAxis:ALAxisVertical];
    [self.pickerView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero excludingEdge:ALEdgeTop];
    [self.pickerView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.toolbar];
    [self.containerView autoCenterInSuperview];
    [self.containerView autoSetDimensionsToSize:CGSizeMake(300, 190)];

    self.hasAddedConstraints = YES;
}

- (void) cancelButtonPressed:(id)sender {
    if (self.cancelBlock) {
        self.cancelBlock(self);
    }
    [self hideFromPresentingViewController];
}

- (void) doneButtonPressed:(id)sender {
    if (self.doneBlock) {
        self.doneBlock(self, self.selectedIndex, [self.pickerStrings objectAtIndex:self.selectedIndex]);
    }
    [self hideFromPresentingViewController];
}

#pragma mark UIPickerViewDataSource
// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return self.pickerStrings.count;
}

#pragma mark UIPickerViewDelegate

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    NSString *title = [self.pickerStrings objectAtIndex:row];
    NSAssert([title isKindOfClass:[NSString class]], @"pickerStrings must only contain strings!");
    return title;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    _selectedIndex = row;
}


- (void) showFromViewController:(UIViewController*)viewController {
    self.alpha = 0.0f;
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 1.0f;
    }];
    self.isVisible = YES;
    NSParameterAssert(viewController != nil);
    NSAssert(self.presentingViewController == nil, @"Don't show it twice in a row!");
    self.presentingViewController = viewController;
    [self.presentingViewController.view addSubview:self];
    [self.constraintsAddedToSuperview addObjectsFromArray:[self autoCenterInSuperview]];
    [self.constraintsAddedToSuperview addObjectsFromArray:[self autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero]];
}

- (void) hideFromPresentingViewController {
    [UIView animateWithDuration:0.2 animations:^{
        self.alpha = 0.0f;
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
        [self removeConstraints:self.constraintsAddedToSuperview];
        [self.constraintsAddedToSuperview removeAllObjects];
        self.presentingViewController = nil;
        self.isVisible = NO;
    }];
}

- (void) setSelectedIndex:(NSUInteger)selectedIndex {
    _selectedIndex = selectedIndex;
    [self.pickerView selectRow:_selectedIndex inComponent:0 animated:YES];
}


@end
