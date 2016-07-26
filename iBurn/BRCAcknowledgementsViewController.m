//
//  BRCAcknowledgementsViewController.m
//  iBurn
//
//  Created by Christopher Ballinger on 8/10/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCAcknowledgementsViewController.h"
@import PureLayout;
#import "BRCAppDelegate.h"

@interface VTAcknowledgementsViewController()
// private methods from superclass
+ (NSString *)defaultAcknowledgementsPlistPath;
- (void)configureHeaderView;
@end

@interface BRCAcknowledgementsViewController ()
@property (nonatomic, strong, readwrite) TTTAttributedLabel *headerLabel;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic) BOOL hasAddedConstraints;
@end

@implementation BRCAcknowledgementsViewController

- (instancetype) initWithHeaderLabel:(TTTAttributedLabel*)headerLabel {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"Pods-iBurnAbstract-iBurn-acknowledgements" ofType:@"plist"];
    if (self = [super initWithPath:path]) {
        self.headerText = headerLabel.text;
        self.headerLabel = headerLabel;
        self.headerLabel.delegate = self;
        [self setupHeaderView];
    }
    return self;
}

- (void) setupHeaderView {
    CGRect headerFrame = CGRectMake(0, 0, 300, 37);
    self.headerView = [[UIView alloc] initWithFrame:headerFrame];
    [self.headerView addSubview:self.headerLabel];
    self.headerView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
}

- (void) updateViewConstraints {
    [super updateViewConstraints];
    if (self.hasAddedConstraints) {
        return;
    }
    [self.headerLabel autoCenterInSuperviewMargins];
    self.hasAddedConstraints = YES;
}

// Overriding private method
- (void)configureHeaderView {
    self.tableView.tableHeaderView = self.headerView;
}

- (void)attributedLabel:(TTTAttributedLabel *)label
   didSelectLinkWithURL:(NSURL *)url {
    [BRCAppDelegate openURL:url fromViewController:self];
}

@end
