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
    
    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectZero];
    searchBar.delegate = self;
    
    UISearchDisplayController *searchDisplayController = [[UISearchDisplayController alloc] initWithSearchBar:searchBar contentsController:self];
    searchDisplayController.delegate = self;
    searchDisplayController.searchResultsDataSource = self;
    
    self.tableView.tableHeaderView = searchBar;
    
    [self.view addSubview:self.segmentedControl];
    [self.view addSubview:self.tableView];
    
    
    [self setupConstraints];
    
    

}

- (void)setupConstraints
{
    id topGuide = self.topLayoutGuide;
    id bottomGuide = self.bottomLayoutGuide;
    NSDictionary *views = NSDictionaryOfVariableBindings(_tableView,_segmentedControl,topGuide,bottomGuide);
    NSDictionary *metrics = @{@"segmentedControlHeight":@(33)};
    
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_segmentedControl]|" options:0 metrics:metrics views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_tableView]|" options:0 metrics:metrics views:views]];
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[topGuide][_segmentedControl(==segmentedControlHeight)]-1-[_tableView][bottomGuide]" options:0 metrics:metrics views:views]];
    
}

- (void)didChangeValueForSegmentedControl:(UISegmentedControl *)sender
{
    //self.segmentedControl.selectedSegmentIndex;
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

////// Optional //////

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [[[UILocalizedIndexedCollation currentCollation] sectionTitles] objectAtIndex:section];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    NSMutableArray *titles = [[[UILocalizedIndexedCollation currentCollation] sectionIndexTitles] mutableCopy];
    [titles insertObject:UITableViewIndexSearch atIndex:0];
    return titles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return [[UILocalizedIndexedCollation currentCollation] sectionForSectionIndexTitleAtIndex:index];
}


@end
