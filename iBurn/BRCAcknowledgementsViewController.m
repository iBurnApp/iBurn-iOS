//
//  BRCAcknowledgementsViewController.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/10/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCAcknowledgementsViewController.h"
#import "PureLayout.h"

@interface VTAcknowledgementsViewController()
// private methods from superclass
+ (NSString *)defaultAcknowledgementsPlistPath;
- (void)configureHeaderView;
@end

@interface BRCAcknowledgementsViewController ()
@property (nonatomic, strong, readwrite) TTTAttributedLabel *headerLabel;
@property (nonatomic, strong, readwrite) BRCSocialButtonsView *socialButtonsView;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic) BOOL hasAddedConstraints;
@end

@implementation BRCAcknowledgementsViewController

- (instancetype) initWithHeaderLabel:(TTTAttributedLabel*)headerLabel {
    if (self = [super initWithAcknowledgementsPlistPath:[[self class] defaultAcknowledgementsPlistPath]]) {
        self.headerText = headerLabel.text;
        self.headerLabel = headerLabel;
        self.headerLabel.delegate = self;
        [self setupHeaderView];
    }
    return self;
}

- (void) setupHeaderView {
    CGRect headerFrame = CGRectMake(0, 0, 300, 100);
    self.headerView = [[UIView alloc] initWithFrame:headerFrame];
    [self.headerView addSubview:self.headerLabel];
    [self setupSocialButtonsView];
}

- (void) updateViewConstraints {
    [super updateViewConstraints];
    if (self.hasAddedConstraints) {
        return;
    }
    [self.socialButtonsView autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsMake(0, 10, 10, 10) excludingEdge:ALEdgeTop];
    [self.socialButtonsView autoSetDimension:ALDimensionHeight toSize:45];
    [self.socialButtonsView autoAlignAxisToSuperviewAxis:ALAxisVertical];
    [self.headerLabel autoPinEdgesToSuperviewEdgesWithInsets:UIEdgeInsetsZero excludingEdge:ALEdgeBottom];
    [self.headerLabel autoPinEdge:ALEdgeBottom toEdge:ALEdgeTop ofView:self.socialButtonsView];
    [self.headerLabel autoAlignAxisToSuperviewAxis:ALAxisVertical];
    self.hasAddedConstraints = YES;
}

- (void) setupSocialButtonsView {
    self.socialButtonsView = [[BRCSocialButtonsView alloc] initWithFrame:CGRectZero];
    [self.headerView addSubview:self.socialButtonsView];
}

// Overriding private method
- (void)configureHeaderView {
    self.tableView.tableHeaderView = self.headerView;
}

- (void)attributedLabel:(TTTAttributedLabel *)label
   didSelectLinkWithURL:(NSURL *)url {
    [[UIApplication sharedApplication] openURL:url];
}


@end
