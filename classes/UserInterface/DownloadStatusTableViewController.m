//
//  DownloadStatusTableViewController.m
//  TrailTracker
//
//  Created by Anna Johnson on 6/6/13.
//
//

#import "DownloadStatusTableViewController.h"
#import "DownloadStatusCenter.h"
#import "DownloadStatus.h"
#import "DownloadStatusTableViewCell.h"
#import "Networking.h"
#import "OrderedDictionary.h"
#import <RMNotifications.h>

@implementation DownloadStatusTableViewController

- (id)initWithStyle:(UITableViewStyle)style {
  self = [super initWithStyle:style];
  if (self) {
    self.title = @"Download Status";
    self.tableView.rowHeight = 75;
  }
  return self;
}


- (void) setInternetStatus {
  if ([[Networking sharedInstance]canConnectToInternet]) {
    if ([[Networking sharedInstance] connectionIs3g]) {
      self.internetStatusLabel.text = @"3G";
    } else {
      self.internetStatusLabel.text  = @"wifi";
    }
  } else {
    self.internetStatusLabel.text  = @"No internet";
  }

}

- (void) viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
  [self.tableView reloadData];
  [self setInternetStatus];
  [self setHeaderLabelText];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setHeaderLabelText) name:RMResumeNetworkOperations object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setHeaderLabelText) name:RMSuspendNetworkOperations object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setHeaderLabelText) name:@"GlobalDownloadingStateChanged" object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newDownloadAdded:) name:@"NewDownloadAdded" object:nil];
  
}

- (void) newDownloadAdded:(NSNotification*) notif {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.tableView reloadData];
  });
}

- (void) setHeaderLabelText {
  [self setInternetStatus];
  if ([[DownloadStatusCenter sharedInstance] downloading]) {
    self.downloadStatusLabel.text = @"Downloading";
  } else {
    self.downloadStatusLabel.text = @"No Downloads in Progress";
  }
  if ([[DownloadStatusCenter sharedInstance] downloading]) {
    [self.downloadIndicator startAnimating];
  } else {
    [self.downloadIndicator stopAnimating];
  }
  
}


- (UILabel*) addLabelWithLabelText:(NSString*)labelText yOrigin:(int)yOrigin toView:(UIView*)view {
  UILabel *labelLabel = [[UILabel alloc]initWithFrame:CGRectMake(5, yOrigin, 90, 22)];
  labelLabel.textAlignment = UITextAlignmentRight;
  labelLabel.backgroundColor = [UIColor clearColor];
  labelLabel.adjustsFontSizeToFitWidth = YES;
  labelLabel.text = labelText;
  [view addSubview:labelLabel];
  
  UILabel *dataLabel = [[UILabel alloc]initWithFrame:CGRectMake(100, yOrigin, 150, 22)];
  dataLabel.adjustsFontSizeToFitWidth = YES;
  dataLabel.backgroundColor = [UIColor clearColor];
  [view addSubview:dataLabel];

  return dataLabel;
}


#define PADDING 10
#pragma mark - table header/footer
- (void) addTableHeader {
  CGRect containerFrame = CGRectMake(0, 0, self.tableView.frame.size.width, 65);
  UIView *container = [[UIView alloc]initWithFrame:containerFrame];
  self.tableView.tableHeaderView = container;

  CGRect headerFrame = CGRectMake(PADDING, PADDING, self.tableView.frame.size.width-PADDING*2, 60);
  UIView *headerView = [[UIView alloc]initWithFrame:headerFrame];
  headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  [container addSubview:headerView];

  self.downloadStatusLabel = [self addLabelWithLabelText:@"Status:" yOrigin:5 toView:headerView];
  self.internetStatusLabel = [self addLabelWithLabelText:@"Connection:" yOrigin:32 toView:headerView];
  [self setHeaderLabelText];
  
  self.downloadIndicator = [[UIActivityIndicatorView alloc]initWithFrame:CGRectMake(headerView.frame.size.width-40, 15, 30, 30)];
  self.downloadIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
  self.downloadIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
  
  [headerView addSubview:self.downloadIndicator];
  
  
}


- (void) viewDidDisappear:(BOOL)animated {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super viewDidDisappear:animated];
}


- (void)viewDidLoad {
  [super viewDidLoad];
  [self addTableHeader];
}


#pragma mark - Table view data source/delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  // Return the number of sections.
  return [[self downloadSections]count];
}


- (OrderedDictionary*) downloadSections {
  OrderedDictionary *sections = [OrderedDictionary dictionary];
  NSArray *downloads = [[DownloadStatusCenter sharedInstance] downloads];
  for (DownloadStatus *d in downloads) {
    if (!sections[d.type]) {
      sections[d.type] = @[d].mutableCopy;
    } else {
      [sections[d.type] addObject:d];
    }
  }
  return sections;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  NSString *key = [[self downloadSections]keyAtIndex:section];
  return [[[self downloadSections]objectForKey:key]count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdentifier = @"DLStatusCell";
  DownloadStatusTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  if (!cell) {
    cell = [[DownloadStatusTableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
  }
  NSString *key = [[self downloadSections]keyAtIndex:indexPath.section];
  NSArray *rowList = [[self downloadSections]objectForKey:key];
  DownloadStatus * ds = [rowList objectAtIndex:indexPath.row];
  cell.downloadStatus = ds;
  return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:NO];
}


- (CGFloat)tableView:(UITableView *)theTableView heightForHeaderInSection:(NSInteger)section {
  return 40;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
  NSString *key = [[self downloadSections]keyAtIndex:section];
  return key;
}


- (void)viewWillLayoutSubviews{
  [super viewWillLayoutSubviews];
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    self.navigationController.view.superview.bounds = CGRectMake(0, 0, 320, self.navigationController.view.frame.size.height);
  }
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}

@end
