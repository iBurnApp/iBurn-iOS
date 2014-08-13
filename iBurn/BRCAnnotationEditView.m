//
//  BRCAnnotationEditView.m
//  iBurn
//
//  Created by David Chiles on 8/12/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCAnnotationEditView.h"
#import "PureLayout.h"

@interface BRCAnnotationEditView () <UITextFieldDelegate>

@property (nonatomic, weak) id<BRCAnnotationEditViewDelegate> delegate;
@property (nonatomic, strong) UITextField* textField;
@property (nonatomic, strong) BButton *saveButton;
@property (nonatomic, strong) BButton *deleteButton;

@property (nonatomic) BOOL didAddConstraints;

@end

@implementation BRCAnnotationEditView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.didAddConstraints = NO;
        
        self.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.8];
        self.alpha = 0.995;
        
        self.textField = [[UITextField alloc] initForAutoLayout];
        self.textField.borderStyle = UITextBorderStyleRoundedRect;
        self.textField.placeholder = @"Name (home, bike, etc)";
        self.textField.returnKeyType = UIReturnKeyDone;
        self.textField.delegate = self;
        self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        
        self.saveButton = [[BButton alloc] initWithFrame:CGRectZero type:BButtonTypeSuccess style:BButtonStyleBootstrapV3];
        self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.saveButton setTitle:@"Save" forState:UIControlStateNormal];
        [self.saveButton addTarget:self action:@selector(doneButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        
        self.deleteButton = [[BButton alloc] initWithFrame:CGRectZero type:BButtonTypeDanger style:BButtonStyleBootstrapV3];
        self.deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.deleteButton setTitle:@"Delete" forState:UIControlStateNormal];
        [self.deleteButton addTarget:self action:@selector(deleteButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        
        [self addSubview:self.textField];
        [self addSubview:self.saveButton];
        [self addSubview:self.deleteButton];
    }
    return self;
}

- (instancetype)initWithDelegate:(id <BRCAnnotationEditViewDelegate>)delegate {
    if (self = [self initWithFrame:CGRectZero]) {
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
    
    [self.deleteButton autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:margin];
    [self.deleteButton autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:margin];
    [self.deleteButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.textField withOffset:margin];
    [self.deleteButton autoPinEdge:ALEdgeRight toEdge:ALEdgeLeft ofView:self.saveButton withOffset:-margin];
    [self.deleteButton autoMatchDimension:ALDimensionWidth toDimension:ALDimensionWidth ofView:self.saveButton];
    
    [self.saveButton autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:margin];
    [self.saveButton autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:margin];
    [self.saveButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.textField withOffset:margin];
    
    self.didAddConstraints = YES;
}

- (void)doneButtonPressed:(id)sender
{
    BRCMapPoint *editedMapPoint = self.mapPoint;
    editedMapPoint.title = self.textField.text;
    editedMapPoint.modifiedDate = [NSDate date];
    [self.textField resignFirstResponder];
    [self.delegate editViewDidSelectSave:self editedMapPoint:editedMapPoint];
    self.mapPoint = nil;
}

- (void)deleteButtonPressed:(id)sender
{
    BRCMapPoint *mapPointToDelete = self.mapPoint;
    [self.textField resignFirstResponder];
    [self.delegate editViewDidSelectDelete:self mapPointToDelete:mapPointToDelete];
    self.mapPoint = nil;
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField {
    [self doneButtonPressed:textField];
    return NO;
}

- (void) setMapPoint:(BRCMapPoint *)mapPoint {
    _mapPoint = [mapPoint copy];
    self.textField.text = mapPoint.title;
}

@end
