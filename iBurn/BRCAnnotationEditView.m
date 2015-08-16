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
        self.textField.placeholder = @"Point Name (optional)";
        self.textField.delegate = self;
        self.textField.autocorrectionType = UITextAutocorrectionTypeNo;
        self.textField.backgroundColor = [UIColor clearColor];
        
        self.saveButton = [[BButton alloc] initWithFrame:CGRectZero type:BButtonTypeSuccess style:BButtonStyleBootstrapV3];
        self.saveButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.saveButton setTitle:@"Save" forState:UIControlStateNormal];
        [self.saveButton addTarget:self action:@selector(doneButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        
        self.deleteButton = [[BButton alloc] initWithFrame:CGRectZero type:BButtonTypeDanger style:BButtonStyleBootstrapV3];
        self.deleteButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.deleteButton setTitle:@"Delete" forState:UIControlStateNormal];
        [self.deleteButton addTarget:self action:@selector(deleteButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        
        
        NSMutableArray *typeButtons = [NSMutableArray array];
        // selector, BRCMapPointType, imageName
        NSArray *buttonInfoArray = @[@[NSStringFromSelector(@selector(homeButtonPressed:)), @"BRCUserPinHome"],
                                @[NSStringFromSelector(@selector(bikeButtonPressed:)), @"BRCUserPinBike"],
                                @[NSStringFromSelector(@selector(starButtonPressed:)), @"BRCUserPinStar"]];
        [buttonInfoArray enumerateObjectsUsingBlock:^(NSArray *buttonInfo, NSUInteger idx, BOOL *stop) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.translatesAutoresizingMaskIntoConstraints = NO;
            NSString *selectorName = buttonInfo[0];
            NSString *imageName = buttonInfo[1];
            [button setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
            [button addTarget:self action:NSSelectorFromString(selectorName) forControlEvents:UIControlEventTouchUpInside];
            [typeButtons addObject:button];
            [self addSubview:button];
        }];
        
        _typeButtons = typeButtons;
        
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
    
    CGFloat buttonSize = 35;
    [self.typeButtons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger idx, BOOL *stop) {
        [button autoSetDimensionsToSize:CGSizeMake(buttonSize, buttonSize)];
        [button autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.textField withOffset:margin];
    }];
    
    [self.typeButtons autoDistributeViewsAlongAxis:ALAxisHorizontal alignedTo:ALAttributeHorizontal withFixedSize:buttonSize insetSpacing:margin];
    
    UIButton *firstTypeButton = self.typeButtons[0];
    
    [self.deleteButton autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:margin];
    [self.deleteButton autoPinEdgeToSuperviewEdge:ALEdgeLeft withInset:margin];
    [self.deleteButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:firstTypeButton withOffset:margin];
    [self.deleteButton autoPinEdge:ALEdgeRight toEdge:ALEdgeLeft ofView:self.saveButton withOffset:-margin];
    [self.deleteButton autoMatchDimension:ALDimensionWidth toDimension:ALDimensionWidth ofView:self.saveButton];
    
    [self.saveButton autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:margin];
    [self.saveButton autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:margin];
    [self.saveButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:firstTypeButton withOffset:margin];
    
    self.didAddConstraints = YES;
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

- (void) setMapPoint:(BRCUserMapPoint *)mapPoint {
    if (!mapPoint) {
        _mapPoint = nil;
        return;
    }
    _mapPoint = [mapPoint copy];
    self.textField.text = mapPoint.title;
    
    // ehhhh flakey
    UIButton *homeButton = self.typeButtons[0];
    UIButton *bikeButton = self.typeButtons[1];
    UIButton *starButton = self.typeButtons[2];
    
    [self.typeButtons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger idx, BOOL *stop) {
        button.highlighted = NO;
    }];
    
    if (mapPoint.type == BRCMapPointTypeUserHome) {
        homeButton.highlighted = YES;
    } else if (mapPoint.type == BRCMapPointTypeUserBike) {
        bikeButton.highlighted = YES;
    } else if (mapPoint.type == BRCMapPointTypeUserStar) {
        starButton.highlighted = YES;
    } else {
        starButton.highlighted = YES;
    }
}

- (void) savePoint:(BRCUserMapPoint*)point ofType:(BRCMapPointType)type {
    NSParameterAssert(point != nil);
    if (!point) {
        return;
    }
    if (self.textField.text.length > 0) {
        point.title = self.textField.text;
    }
    if (!point.title.length) {
        point.title = @"Saved Pin";
    }
    point.type = type;
    point.modifiedDate = [NSDate date];
    [self.textField resignFirstResponder];
    [self.delegate editViewDidSelectSave:self editedMapPoint:point];
    self.mapPoint = nil;
}


#pragma mark Button Events

- (void)doneButtonPressed:(id)sender
{
    [self savePoint:self.mapPoint ofType:self.mapPoint.type];
}

- (void)deleteButtonPressed:(id)sender
{
    BRCUserMapPoint *mapPointToDelete = self.mapPoint;
    [self.textField resignFirstResponder];
    [self.delegate editViewDidSelectDelete:self mapPointToDelete:mapPointToDelete];
    self.mapPoint = nil;
}

- (void) bikeButtonPressed:(id)sender {
    self.mapPoint.title = @"Bike";
    [self savePoint:self.mapPoint ofType:BRCMapPointTypeUserBike];
}

- (void) starButtonPressed:(id)sender {
    if (!self.mapPoint.title.length) {
        self.mapPoint.title = @"Saved Pin";
    }
    [self savePoint:self.mapPoint ofType:BRCMapPointTypeUserStar];
}

- (void) homeButtonPressed:(id)sender {
    self.mapPoint.title = @"Home";
    [self savePoint:self.mapPoint ofType:BRCMapPointTypeUserHome];
}

@end
