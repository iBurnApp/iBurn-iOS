//
//  DownloadStatusTableViewCell.h
//  TrailTracker
//
//  Created by Anna Johnson on 6/7/13.
//
//

#import "DownloadStatus.h"

@interface DownloadStatusTableViewCell : UITableViewCell {
  NSTimer * refreshTimer;
}

@property (nonatomic, retain) DownloadStatus * downloadStatus;
@property (nonatomic, retain) UILabel *titleLabel, *slugLabel, *sizeLabel, *speedLabel;
@property (nonatomic, retain) UIProgressView *progressView;
@property (nonatomic, retain) UIImageView *icon, *overlayIcon;

@end
