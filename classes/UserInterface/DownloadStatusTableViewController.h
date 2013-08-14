//
//  DownloadStatusTableViewController.h
//  TrailTracker
//
//  Created by Anna Johnson on 6/6/13.
//
//

@interface DownloadStatusTableViewController : UITableViewController

@property (nonatomic, retain) UILabel *internetStatusLabel, *downloadStatusLabel;
@property (nonatomic, retain) UIActivityIndicatorView *downloadIndicator;

@end
