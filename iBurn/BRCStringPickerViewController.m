//
//  BRCStringPickerViewController.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/6/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCStringPickerViewController.h"
#import "PureLayout.h"
#import "UIColor+iBurn.h"

@interface BRCStringPickerViewController ()
@property (nonatomic, readwrite) BOOL hasAddedConstraints;
@end

@implementation BRCStringPickerViewController

- (instancetype)initWithPickerStrings:(NSArray *)pickerStrings initialSelection:(NSUInteger)initialSelection doneBlock:(BRCStringPickerDoneBlock)doneBlock {
    if (self = [super init]) {
        _pickerStrings = [pickerStrings copy];
        self.doneBlock = doneBlock;
        [self setupPickerViewWithInitialSelection:initialSelection];
    }
    return self;
}

- (void) setupPickerViewWithInitialSelection:(NSUInteger)initialSelection {
    _pickerView = [[UIPickerView alloc] initForAutoLayout];
    self.pickerView.dataSource = self;
    [self.pickerView selectRow:initialSelection inComponent:0 animated:NO];
    self.pickerView.delegate = self;
}

- (void) viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.pickerView];
    [self.view setNeedsUpdateConstraints];
}

- (void)updateViewConstraints {
    [super updateViewConstraints];
    if (self.hasAddedConstraints) {
        return;
    }
    [self.pickerView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero];
    self.hasAddedConstraints = YES;
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if (self.doneBlock) {
        self.doneBlock(self, self.selectedIndex, [self.pickerStrings objectAtIndex:self.selectedIndex]);
    }
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

- (void) setSelectedIndex:(NSUInteger)selectedIndex {
    _selectedIndex = selectedIndex;
    [self.pickerView selectRow:_selectedIndex inComponent:0 animated:YES];
}


@end
