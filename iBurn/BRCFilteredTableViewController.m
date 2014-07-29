//
//  BRCFilteredTableViewController.m
//  iBurn
//
//  Created by Christopher Ballinger on 7/28/14.
//  Copyright (c) 2014 Burning Man Earth. All rights reserved.
//

#import "BRCFilteredTableViewController.h"

@interface BRCFilteredTableViewController ()

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;

@end

@implementation BRCFilteredTableViewController

- (instancetype)initWithItems:(NSArray *)items
{
    if (self = [super init]) {
        self.segmentedControl = [[UISegmentedControl alloc] initWithItems:items];
        self.segmentedControl.translatesAutoresizingMaskIntoConstraints = NO;
        self.segmentedControl.selectedSegmentIndex = 0;
        
        [self.segmentedControl addTarget:self action:@selector(didChangeValueForSegmentedControl:) forControlEvents:UIControlEventValueChanged];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [self.view addSubview:self.segmentedControl];
    [self.view addSubview:self.tableView];
    
    
    [self setupConstraints];
}

- (void)setupConstraints
{
    id topGuide = self.topLayoutGuide;
    NSDictionary *views = NSDictionaryOfVariableBindings(_tableView,_segmentedControl,topGuide);
    NSDictionary *metrics = @{@"segmentedControlHeight":@(33)};
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_segmentedControl]|" options:0 metrics:metrics views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_tableView]|" options:0 metrics:metrics views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[topGuide][_segmentedControl(==segmentedControlHeight)]-2-[_tableView]|" options:0 metrics:metrics views:views]];
    
}

- (void)didChangeValueForSegmentedControl:(UISegmentedControl *)sender
{
    self.segmentedControl.selectedSegmentIndex;
}

#pragma - mark UITableViewDataSource Methods

////// Required //////
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"asdf"];
    cell.textLabel.text = @"Name";
    cell.detailTextLabel.text = @"detail";
    return cell;
}

@end
