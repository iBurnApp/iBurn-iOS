//
//  BRCAnnotationEditView.m
//  iBurn
//
//  Created by David Chiles on 8/12/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCAnnotationEditView.h"
#import "PureLayout.h"
#import "BButton.h"

@interface BRCAnnotationEditView ()

@property (nonatomic, weak) id<BRCAnnotationEditViewDelegate> delegate;
@property (nonatomic, strong) UITextField* textField;
@property (nonatomic, strong) UIButton *doneButton;
@property (nonatomic, strong) UIButton *deleteButton;

@property (nonatomic) BOOL didAddConstraints;

@end

@implementation BRCAnnotationEditView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        
        self.didAddConstraints = NO;
        
        self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.8];
        self.alpha = 0.995;
        
        self.textField = [[UITextField alloc] initForAutoLayout];
        self.textField.borderStyle = UITextBorderStyleRoundedRect;
        self.textField.placeholder = @"Name (home, bike, etc)";
        
        self.doneButton = [[BButton alloc] initWithFrame:CGRectZero type:BButtonTypeDefault style:BButtonStyleBootstrapV3];
        self.doneButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.doneButton setTitle:@"Done" forState:UIControlStateNormal];
        [self.doneButton addTarget:self action:@selector(doneButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        
        self.deleteButton = [[BButton alloc] initWithFrame:CGRectZero type:BButtonTypeDanger style:BButtonStyleBootstrapV3];
        self.deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.deleteButton setTitle:@"Delete" forState:UIControlStateNormal];
        [self.deleteButton addTarget:self action:@selector(deleteButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        
        [self addSubview:self.textField];
        [self addSubview:self.doneButton];
        [self addSubview:self.deleteButton];
    }
    return self;
}

- (instancetype)initWithText:(NSString *)text delegate:(id<BRCAnnotationEditViewDelegate>)delegate
{
    if (self = [self initWithFrame:CGRectZero]) {
        self.textField.text = text;
        self.delegate = delegate;
    }
    return self;
}

- (void)updateConstraints
{
    [super updateConstraints];
    if (self.didAddConstraints) {
        return;
    }
    
    CGFloat margin = 10.0;
    CGFloat textFieldHeight = 26.0;
    
    [self.textField autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsMake(margin, margin, margin, margin) excludingEdge:ALEdgeBottom];
    [self.textField autoSetDimension:ALDimensionHeight toSize:textFieldHeight];
    
    [self.doneButton autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:margin];
    [self.doneButton autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:margin];
    [self.doneButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.textField withOffset:margin];
    [self.doneButton autoPinEdge:ALEdgeRight toEdge:ALEdgeLeft ofView:self.deleteButton withOffset:-margin];
    [self.doneButton autoMatchDimension:ALDimensionWidth toDimension:ALDimensionWidth ofView:self.deleteButton];
    
    [self.deleteButton autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:margin];
    [self.deleteButton autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:margin];
    [self.deleteButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.textField withOffset:margin];
    
    self.didAddConstraints = YES;
}

- (void)doneButtonPressed:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(editViewDidSelectDone:text:)]) {
        [self.delegate editViewDidSelectDone:self text:self.textField.text];
    }
}

- (void)deleteButtonPressed:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(editViewDidSelectDelete:)]) {
        [self.delegate editViewDidSelectDelete:self];
    }
}
                           

@end
